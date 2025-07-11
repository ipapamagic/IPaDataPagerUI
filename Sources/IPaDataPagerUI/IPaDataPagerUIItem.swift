//
//  IPaDataPagerUIItem.swift
//  IPaDataPagerUI
//
//  Created by IPa Chen on 2024/2/15.
//

import UIKit

public struct IPaDataPagerUIItem<SectionIdentifierType:Hashable & Sendable, DataType: Sendable>: Hashable,IPaDataPagerItemType,Sendable {
    
    
    public typealias SectionType = SectionIdentifierType
    public static func == (lhs: IPaDataPagerUIItem, rhs: IPaDataPagerUIItem) -> Bool {
        return lhs.index == rhs.index && lhs.section == rhs.section
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(index)
        hasher.combine(section)
    }
    public var isLoadingType: Bool {
        return self.index < 0
    }
    public var index:Int
    public var data:DataType?
    public var section :SectionIdentifierType
    public init(section:SectionIdentifierType,index: Int, data: DataType? = nil) {
        self.index = index
        self.section = section
        self.data = data
    }
    public static func createLoadingItem(for section: SectionIdentifierType) -> IPaDataPagerUIItem<SectionIdentifierType,DataType> {
        return IPaDataPagerUIItem(section:section, index: -1, data: nil)
    }
    
}
