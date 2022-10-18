//
//  IPaCollectionViewDataPagerUI.swift
//  IPaUIKitHelper
//
//  Created by IPa Chen on 2022/4/5.
//

import UIKit

open class IPaCollectionViewDataPagerUI<SectionIdentifierType,ItemIdentifierType>: IPaDataPagerUI<SectionIdentifierType,ItemIdentifierType,UICollectionView,UICollectionViewCell> where SectionIdentifierType:Hashable,ItemIdentifierType:Hashable,ItemIdentifierType:IPaDataPagerUIHasLoadType {
    public weak var dataSource:UICollectionViewDiffableDataSource<SectionIdentifierType,ItemIdentifierType>!
    public init(_ dataSource:UICollectionViewDiffableDataSource<SectionIdentifierType,ItemIdentifierType>,section:SectionIdentifierType) {
        self.dataSource = dataSource
        super.init(section)
    }
    
    override func onInsert(_ pageInfo:PageInfo,loadingItentifier:ItemIdentifierType) {
        super.onInsert(pageInfo,loadingItentifier:loadingItentifier)
        
        var snapshot = self.dataSource.snapshot()
        snapshot.deleteItems([loadingItentifier])
        if pageInfo.datas.count > 0 {
            snapshot.appendItems(pageInfo.datas, toSection: self.section)
        }
        if self.currentPage < self.totalPage {
            snapshot.appendItems( [self.createLoadingType(self.currentPage + 1)], toSection: self.section)
        }
        
        self.dataSource!.apply(snapshot)
    }
    open func insertLoadingType(_ page:Int = 1) {
        var snapshot = self.dataSource.snapshot()
        snapshot.appendItems([self.createLoadingType(page)], toSection: self.section)
        self.dataSource.apply(snapshot)
    }
    open override func provideLoadingCell(_ collectionView:UICollectionView,indexPath:IndexPath,itemIdentifier:ItemIdentifierType) -> UICollectionViewCell {
        fatalError("need implement provideLoadingCell")
    }
    open override func provideDataCell(_ collectionView:UICollectionView,indexPath:IndexPath,itemIdentifier:ItemIdentifierType) -> UICollectionViewCell {
        fatalError("need implement provideDataCell")
    }
}
