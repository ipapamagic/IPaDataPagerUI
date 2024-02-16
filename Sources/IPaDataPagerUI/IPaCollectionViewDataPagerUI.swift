//
//  IPaCollectionViewDataPagerUI.swift
//  IPaUIKitHelper
//
//  Created by IPa Chen on 2022/4/5.
//

import UIKit

open class IPaCollectionViewDataPagerUI<SectionIdentifierType,ItemIdentifierType>: IPaDataPagerUI<SectionIdentifierType,ItemIdentifierType,UICollectionView,UICollectionViewCell> where SectionIdentifierType:Hashable,ItemIdentifierType:Hashable,ItemIdentifierType:IPaDataPagerItemType {
    public weak var dataSource:UICollectionViewDiffableDataSource<SectionIdentifierType,ItemIdentifierType>!
    public init(_ dataSource:UICollectionViewDiffableDataSource<SectionIdentifierType,ItemIdentifierType>,section:SectionIdentifierType) {
        self.dataSource = dataSource
        super.init(section)
        
    }
    open override func provideLoadingCell(_ collectionView:UICollectionView,indexPath:IndexPath,itemIdentifier:ItemIdentifierType) -> UICollectionViewCell {
        fatalError("need implement provideLoadingCell")
    }
    open override func provideDataCell(_ collectionView:UICollectionView,indexPath:IndexPath,itemIdentifier:ItemIdentifierType) -> UICollectionViewCell {
        fatalError("need implement provideDataCell")
    }
    override func currentSnapshot() -> NSDiffableDataSourceSnapshot<SectionIdentifierType,ItemIdentifierType> {
        return self.dataSource.snapshot()
    }
    override func apply(snapshot:NSDiffableDataSourceSnapshot<SectionIdentifierType,ItemIdentifierType>) {
        self.dataSource.apply(snapshot)
    }
    
    
    
}
