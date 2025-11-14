//
//  IPaTableViewDataPagerUI.swift
//  IPaUIKitHelper
//
//  Created by IPa Chen on 2022/4/5.
//

import UIKit

open class IPaTableViewDataPagerUI<SectionIdentifierType,ItemIdentifierType>: IPaDataPagerUI<SectionIdentifierType,ItemIdentifierType,UITableView,UITableViewCell> where SectionIdentifierType:Hashable,ItemIdentifierType:Hashable,ItemIdentifierType:IPaDataPagerItemType {
    public weak var dataSource:UITableViewDiffableDataSource<SectionIdentifierType,ItemIdentifierType>!
    
    public init(_ dataSource:UITableViewDiffableDataSource<SectionIdentifierType,ItemIdentifierType>,section:SectionIdentifierType) {
        self.dataSource = dataSource
        
        super.init(section)
    }

    open override func provideLoadingCell(_ tableView:UITableView,indexPath:IndexPath,itemIdentifier:ItemIdentifierType) -> UITableViewCell {
        fatalError("need implement provideLoadingCell")
    }
    open override func provideDataCell(_ tableView:UITableView,indexPath:IndexPath,itemIdentifier:ItemIdentifierType) -> UITableViewCell {
        fatalError("need implement provideDataCell")
    }
    override func createCurrentSnapshot() -> NSDiffableDataSourceSnapshot<SectionIdentifierType,ItemIdentifierType> {
        return self.dataSource.snapshot()
    }
    open override func applySnapshot() {
        self.dataSource.apply(self.currentSnapshot)
    }

}
