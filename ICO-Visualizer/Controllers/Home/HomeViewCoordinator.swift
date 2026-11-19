//
//  HomeViewCoordinator.swift
//  ICO-visualizer
//
//  Created by Anonymous on 03/11/21.
//  Copyright © 2021 Anonymous. All rights reserved.
//

import Foundation

class HomeViewCoordinator {
    
    private var currentPage: Int = 1
    
    public var videos: [Video] = []
    
    public var searchText: String? = nil
    public var category: String? = nil
    public var ordering: String = "mostviewed"
    public var period: String? = nil
    private var generation = 0
    
    private var delegate: HomeViewDelegate!
    
    init(_ delegate: HomeViewDelegate) {
        self.delegate = delegate
    }
    
    func loadData(){
        let gen = generation
        APIService.shared.sendSearchRequest(searchText: self.searchText, category: self.category, page: currentPage, ordering: self.ordering, period: self.period) { result in
            guard gen == self.generation else { return } // stale response after sort/search change
            switch result {
            case .success(let videos):
                self.videos.append(contentsOf: videos.videos)
                self.delegate.reloadView()
            case .failure(let error):
                if let errorRes = error as? APIServiceError {
                    switch errorRes {
                    case .unknown:
                        self.delegate.showError(message: "Unknown error".localized)
                    case .decodeError(let error):
                        self.delegate.showError(message: error.localizedDescription)
                    case .noDataFound:
                        self.delegate.showError(message: "No data found".localized)
                    case .error(let errorResponse):
                        if self.videos.count <= 0 {
                            self.delegate.showError(message: errorResponse.message)
                        } else {
                            self.delegate.reloadView()
                        }
                    }

                }
                else if self.videos.count <= 0 {
                    self.delegate.showError(message: error.localizedDescription)
                }
                print(error)
            }
        }
    }
    
    func applySort(ordering: String, period: String?){
        self.generation += 1
        self.ordering = ordering
        self.period = period
        self.currentPage = 1
        self.videos = []
        self.loadData()
    }

    func search(searchText: String?){
        self.generation += 1
        self.searchText = searchText
        self.category = nil
        self.currentPage = 1
        self.loadData()
    }
    
    func searchForCategory(category : String){
        self.generation += 1
        self.currentPage = 1
        self.searchText = nil
        self.category = category
        self.loadData()
    }
    
    func fetchNext(){
        currentPage += 1
        self.loadData()
    }
}
