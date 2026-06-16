-- =====================================================================
-- Migration: organizer_favorites + referral_codes + referral_redemptions
-- =====================================================================
-- Aggiunge le tabelle di supporto per:
--   * preferiti organizer lato cliente
--   * programma referral con codici univoci e tracking riscatti
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. PREFERITI ORGANIZER
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.organizer_favorites (
    client_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    organizer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (client_id, organizer_id)
);

CREATE INDEX IF NOT EXISTS organizer_favorites_client_idx
    ON public.organizer_favorites(client_id, created_at DESC);

ALTER TABLE public.organizer_favorites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS organizer_favorites_select ON public.organizer_favorites;
CREATE POLICY organizer_favorites_select
    ON public.organizer_favorites
    FOR SELECT
    USING (auth.uid() = client_id);

DROP POLICY IF EXISTS organizer_favorites_insert ON public.organizer_favorites;
CREATE POLICY organizer_favorites_insert
    ON public.organizer_favorites
    FOR INSERT
    WITH CHECK (auth.uid() = client_id);

DROP POLICY IF EXISTS organizer_favorites_delete ON public.organizer_favorites;
CREATE POLICY organizer_favorites_delete
    ON public.organizer_favorites
    FOR DELETE
    USING (auth.uid() = client_id);


-- ---------------------------------------------------------------------
-- 2. REFERRAL CODES
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.referral_codes (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id               UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    code                  TEXT NOT NULL UNIQUE,
    uses_count            INT  NOT NULL DEFAULT 0,
    reward_granted_count  INT  NOT NULL DEFAULT 0,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS referral_codes_code_idx ON public.referral_codes(code);

ALTER TABLE public.referral_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS referral_codes_select_own ON public.referral_codes;
CREATE POLICY referral_codes_select_own
    ON public.referral_codes
    FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS referral_codes_lookup ON public.referral_codes;
-- Necessario per validare i codici dei riscatti: leggiamo solo (id, user_id, code)
CREATE POLICY referral_codes_lookup
    ON public.referral_codes
    FOR SELECT
    USING (true);

DROP POLICY IF EXISTS referral_codes_insert_own ON public.referral_codes;
CREATE POLICY referral_codes_insert_own
    ON public.referral_codes
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);


-- ---------------------------------------------------------------------
-- 3. REFERRAL REDEMPTIONS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.referral_redemptions (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code_id       UUID NOT NULL REFERENCES public.referral_codes(id) ON DELETE CASCADE,
    redeemer_id   UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    code          TEXT NOT NULL,
    redeemed_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    reward_granted BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS referral_redemptions_code_idx
    ON public.referral_redemptions(code_id);

ALTER TABLE public.referral_redemptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS referral_redemptions_select_own ON public.referral_redemptions;
CREATE POLICY referral_redemptions_select_own
    ON public.referral_redemptions
    FOR SELECT
    USING (
        auth.uid() = redeemer_id
        OR auth.uid() IN (
            SELECT user_id FROM public.referral_codes WHERE id = referral_redemptions.code_id
        )
    );

DROP POLICY IF EXISTS referral_redemptions_insert ON public.referral_redemptions;
CREATE POLICY referral_redemptions_insert
    ON public.referral_redemptions
    FOR INSERT
    WITH CHECK (auth.uid() = redeemer_id);


-- ---------------------------------------------------------------------
-- 4. VIEW: referral_stats
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW public.referral_stats AS
SELECT
    rc.user_id,
    COUNT(rr.id)                                              AS total_invited,
    COUNT(rr.id) FILTER (WHERE rr.reward_granted = true)      AS total_activated,
    rc.reward_granted_count                                   AS pro_months_earned
FROM public.referral_codes rc
LEFT JOIN public.referral_redemptions rr ON rr.code_id = rc.id
GROUP BY rc.user_id, rc.reward_granted_count;

GRANT SELECT ON public.referral_stats TO authenticated;


-- ---------------------------------------------------------------------
-- 5. TRIGGER: incrementa uses_count quando arriva un nuovo riscatto
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_referral_increment_uses()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE public.referral_codes
    SET uses_count = uses_count + 1
    WHERE id = NEW.code_id;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_referral_increment_uses ON public.referral_redemptions;
CREATE TRIGGER trg_referral_increment_uses
    AFTER INSERT ON public.referral_redemptions
    FOR EACH ROW EXECUTE FUNCTION public.fn_referral_increment_uses();
