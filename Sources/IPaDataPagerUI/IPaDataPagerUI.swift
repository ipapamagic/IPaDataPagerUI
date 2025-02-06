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
    var dataItemIdentifiers = [ItemIdentifierType]()
    var loadingIdentifier:ItemIdentifierType?
    public private(set) var section:SectionIdentifierType
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
    open func resetLoading(_ insertLoadingItem:Bool = true) {
        self.loadingPage = 0
        self.currentPage = 0
        self.totalPage = 1
        
        var items = self.dataItemIdentifiers
        if let loadingIdentifier = loadingIdentifier {
            items.append(loadingIdentifier)
            self.loadingIdentifier = nil
        }
        if !items.isEmpty {
            var snapshot = self.currentSnapshot()
            snapshot.deleteItems(items)
            self.dataItemIdentifiers.removeAll()
            self.apply(snapshot:snapshot)
        }
        if insertLoadingItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.insertLoadingItem()
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
    func insertLoadingItem() {
        var snapshot = self.currentSnapshot()
        let loadingItem = ItemIdentifierType.createLoadingItem(for: self.section as! ItemIdentifierType.SectionType)
        self.loadingIdentifier = loadingItem
        snapshot.appendItems([loadingItem], toSection: self.section)
        self.apply(snapshot: snapshot)
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
            let pageInfo = await self.loadData(nextPage)
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async {  
                    if pageInfo.currentPage == self.loadingPage {
                        self.totalPage = pageInfo.totalPage
                        self.currentPage = pageInfo.currentPage
                        self.loadingPage = 0
                        
                        var snapshot = self.currentSnapshot()
                        if let itemIdentifier = self.loadingIdentifier {
                            snapshot.deleteItems([itemIdentifier])
                            self.loadingIdentifier = nil
                        }
                        
                        if pageInfo.datas.count > 0 {
                            snapshot.appendItems(pageInfo.datas, toSection: self.section)
                            self.dataItemIdentifiers.append(contentsOf: pageInfo.datas)
                        }
                        if self.currentPage < self.totalPage {
                            let loadingItem = ItemIdentifierType.createLoadingItem(for: self.section as! ItemIdentifierType.SectionType)
                            self.loadingIdentifier = loadingItem
                            snapshot.appendItems([loadingItem], toSection: self.section)
                        }
                        self.apply(snapshot: snapshot)
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
    func currentSnapshot() -> NSDiffableDataSourceSnapshot<SectionIdentifierType,ItemIdentifierType> {
        fatalError("need implement currentSnapshot(_:complete:)")
    }
    func apply(snapshot:NSDiffableDataSourceSnapshot<SectionIdentifierType,ItemIdentifierType>) {
        fatalError("need implement applySnapshot(_:complete:)")
    }
   

}
