//
//  IPaDataPagerUI.swift
//  IPaUIKitHelper
//
//  Created by IPa Chen on 2022/4/5.
//

import UIKit

public protocol IPaDataPagerItemType {
    associatedtype SectionType
    var isLoadingType:Bool { get }
    static func createLoadingItem(for section:SectionType)  -> Self
}

open class IPaDataPagerUI<SectionIdentifierType,ItemIdentifierType: Sendable,ContainerType,CellType>: NSObject where SectionIdentifierType:Hashable,ItemIdentifierType:Hashable,ItemIdentifierType:IPaDataPagerItemType {
    typealias SectionType = SectionIdentifierType
    var totalPage:Int = 1
    var currentPage:Int = 0
    var loadingPage:Int = 0
    var loadingIdentifier:ItemIdentifierType?
    public private(set) var section:SectionIdentifierType
    var currentSnapshot:NSDiffableDataSourceSnapshot<SectionIdentifierType,ItemIdentifierType>!
    public struct PageInfo : Sendable{
        var totalPage:Int
        var currentPage:Int
        var datas:[ItemIdentifierType]
        public init(currentPage:Int,totalPage:Int,datas:[ItemIdentifierType]) {
            self.currentPage = currentPage
            self.totalPage = totalPage
            self.datas = datas
        }
    }
    init(_ section:SectionIdentifierType)  {
        self.section = section
        super.init()
    }
    open func resetLoading(_ initialLoading:Bool = true) {
        self.loadingPage = 0
        self.currentPage = 0
        self.totalPage = 1
        self.currentSnapshot = self.createCurrentSnapshot()
        var items = self.itemIdentifiers(inSection: self.section)
        self.loadingIdentifier = nil
        if !items.isEmpty {
            self.deleteItems(items)
            if initialLoading {
                let loadingItem = self.createLoadingItem()
                self.appendItems([loadingItem], toSection: self.section)
                self.reloadSections([self.section])
                self.applySnapshot()
                Task {
                    await self.loadNextPage()
                }
            }
            else {
                self.applySnapshot()
            }
            
        }
        else if initialLoading {
            self.currentSnapshot = self.createCurrentSnapshot()
            let loadingItem = self.createLoadingItem()
            self.appendItems([loadingItem], toSection: self.section)
            self.reloadSections([self.section])
            self.applySnapshot()
            Task {
                await self.loadNextPage()
            }
        }
        
    }
    public func provideCell(_ view:ContainerType,indexPath:IndexPath,itemIdentifier:ItemIdentifierType)  -> CellType {
        if itemIdentifier.isLoadingType {
            Task {
                await loadNextPage()
            }
            return self.provideLoadingCell(view, indexPath: indexPath, itemIdentifier: itemIdentifier)
        }
        else {
            return self.provideDataCell(view, indexPath: indexPath, itemIdentifier: itemIdentifier)
        }
    }
    public func createLoadingItem() -> ItemIdentifierType {
        let loadingItem = ItemIdentifierType.createLoadingItem(for: self.section as! ItemIdentifierType.SectionType)
        self.loadingIdentifier = loadingItem
        return loadingItem
    }
    
    func provideLoadingCell(_ view:ContainerType,indexPath:IndexPath,itemIdentifier:ItemIdentifierType) -> CellType {
        fatalError("need implement provideLoadingCell()")
    }
    func provideDataCell(_ view:ContainerType,indexPath:IndexPath,itemIdentifier:ItemIdentifierType) -> CellType {
        fatalError("need implement provideDataCell()")
    }
    
    @MainActor
    public func loadNextPage() async {
        let nextPage = self.currentPage + 1
        if self.loadingPage == 0 {
            self.loadingPage = nextPage
            self.currentSnapshot = self.createCurrentSnapshot()
            let pageInfo = await self.loadData(nextPage)
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async {  
                    if pageInfo.currentPage == self.loadingPage {
                        self.totalPage = pageInfo.totalPage
                        self.currentPage = pageInfo.currentPage
                        self.loadingPage = 0
                        
                        if let itemIdentifier = self.loadingIdentifier {
                            self.currentSnapshot.deleteItems([itemIdentifier])
                            self.loadingIdentifier = nil
                        }
                        
                        if pageInfo.datas.count > 0 {
                            self.currentSnapshot.appendItems(pageInfo.datas, toSection: self.section)
                        }
                        if self.currentPage < self.totalPage {
                            let loadingItem = ItemIdentifierType.createLoadingItem(for: self.section as! ItemIdentifierType.SectionType)
                            self.loadingIdentifier = loadingItem
                            self.currentSnapshot.appendItems([loadingItem], toSection: self.section)
                        }
                        self.applySnapshot()
                    }
                    continuation.resume()
                }
            }
            
            
        }
    }
    open func loadData(_ page:Int) async  -> PageInfo {
        fatalError("need implement loadData(_:)")
    }
//    open func loadData(_ page:Int,complete:@escaping (PageInfo)->()) {
//        fatalError("need implement loadData(_:complete:)")
//    }
    func createCurrentSnapshot() -> NSDiffableDataSourceSnapshot<SectionIdentifierType,ItemIdentifierType> {
        fatalError("need implement currentSnapshot(_:complete:)")
    }
    func applySnapshot() {
        fatalError("need implement applySnapshot(_:complete:)")
    }
   

}
// Snapshot control
extension IPaDataPagerUI {
   
    public var numberOfItems: Int {
        return self.currentSnapshot.numberOfItems
    }
    
    public var numberOfSections: Int {
        return self.currentSnapshot.numberOfSections
    }
    
    public var sectionIdentifiers: [SectionIdentifierType] {
        return self.currentSnapshot.sectionIdentifiers
    }
    
    public var itemIdentifiers: [ItemIdentifierType] {
        return self.currentSnapshot.itemIdentifiers
    }
    
    @available(iOS 15.0, tvOS 15.0, *)
    public var reloadedSectionIdentifiers: [SectionIdentifierType] {
        return self.currentSnapshot.reloadedSectionIdentifiers
    }
    
    @available(iOS 15.0, tvOS 15.0, *)
    public var reloadedItemIdentifiers: [ItemIdentifierType] {
        return self.currentSnapshot.reloadedItemIdentifiers
    }
    
    @available(iOS 15.0, tvOS 15.0, *)
    public var reconfiguredItemIdentifiers: [ItemIdentifierType] {
        return self.currentSnapshot.reconfiguredItemIdentifiers
    }
    
    public func numberOfItems(inSection identifier: SectionIdentifierType) -> Int {
        return self.currentSnapshot.numberOfItems(inSection: identifier)
    }
    
    public func itemIdentifiers(inSection identifier: SectionIdentifierType) -> [ItemIdentifierType]
    {
        return self.currentSnapshot.itemIdentifiers(inSection: identifier)
    }
    public  func appendItems(_ identifiers: [ItemIdentifierType], toSection sectionIdentifier: SectionIdentifierType? = nil) {
        self.currentSnapshot.appendItems(identifiers,toSection:  sectionIdentifier)
    }
    
    public func insertItems(_ identifiers: [ItemIdentifierType], beforeItem beforeIdentifier: ItemIdentifierType) {
        self.currentSnapshot.insertItems(identifiers, beforeItem: beforeIdentifier)
    }
    
    public func insertItems(_ identifiers: [ItemIdentifierType], afterItem afterIdentifier: ItemIdentifierType) {
        self.currentSnapshot.insertItems(identifiers, afterItem: afterIdentifier)
    }
    
    public func deleteItems(_ identifiers: [ItemIdentifierType]) {
        self.currentSnapshot.deleteItems(identifiers)
    }
    
    public func deleteAllItems() {
        self.currentSnapshot.deleteAllItems()
    }
    
    public func moveItem(_ identifier: ItemIdentifierType, beforeItem toIdentifier: ItemIdentifierType) {
        self.currentSnapshot.moveItem(identifier, beforeItem: toIdentifier)
    }
    
    public func moveItem(_ identifier: ItemIdentifierType, afterItem toIdentifier: ItemIdentifierType) {
        self.currentSnapshot.moveItem(identifier, afterItem: toIdentifier)
    }
    
    public func reloadItems(_ identifiers: [ItemIdentifierType]) {
        self.currentSnapshot.reloadItems(identifiers)
    }
    
    @available(iOS 15.0, tvOS 15.0, *)
    public func reconfigureItems(_ identifiers: [ItemIdentifierType]) {
        self.currentSnapshot.reconfigureItems(identifiers)
    }
    
    public func appendSections(_ identifiers: [SectionIdentifierType]) {
        self.currentSnapshot.appendSections(identifiers)
    }
    
    public func insertSections(_ identifiers: [SectionIdentifierType], beforeSection toIdentifier: SectionIdentifierType) {
        self.currentSnapshot.insertSections(identifiers,beforeSection:toIdentifier)
    }
    
    public func insertSections(_ identifiers: [SectionIdentifierType], afterSection toIdentifier: SectionIdentifierType) {
        self.currentSnapshot.insertSections(identifiers,afterSection:toIdentifier)
    }
    public func deleteSections(_ identifiers: [SectionIdentifierType]) {
        self.currentSnapshot.deleteSections(identifiers)
    }
    
    public func moveSection(_ identifier: SectionIdentifierType, beforeSection toIdentifier: SectionIdentifierType) {
        self.currentSnapshot.moveSection(identifier,beforeSection:toIdentifier)
    }
    
    public func moveSection(_ identifier: SectionIdentifierType, afterSection toIdentifier: SectionIdentifierType) {
        self.currentSnapshot.moveSection(identifier,afterSection:toIdentifier)
    }
    
    public func reloadSections(_ identifiers: [SectionIdentifierType]) {
        self.currentSnapshot.reloadSections(identifiers)
    }
}
