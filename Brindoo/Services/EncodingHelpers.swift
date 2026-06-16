//
//  EncodingHelpers.swift
//  Brindoo
//
//  Workaround per un comportamento di Codable sintetizzato.
//
//  Swift genera automaticamente `encode(to:)` per le proprietà Optional usando
//  `encodeIfPresent`: con valore `nil` la chiave viene **omessa** dal JSON.
//
//  Quando inviamo una UPDATE a PostgREST con il payload `{}` (chiave omessa),
//  la colonna NON viene toccata. Per settare esplicitamente una colonna a NULL
//  serve mandare `{"colonna": null}`.
//
//  `NullableColumnUpdate` forza la presenza della chiave anche quando il valore
//  è nil.
//

import Foundation

struct NullableColumnUpdate: Encodable {
    let column: String
    let value: String?

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: DynamicCodingKey.self)
        try c.encode(value, forKey: DynamicCodingKey(stringValue: column)!)
    }
}

struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}
