//
//  PeerMediaGridController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 26/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac
import TGUIKit

public enum ChatHistoryNodeHistoryState: Equatable {
    case loading
    case loaded(isEmpty: Bool)
}

struct ChatHistoryGridViewTransition {
    let historyView: ChatHistoryView
    let topOffsetWithinMonth: Int
    let deleteItems: [Int]
    let insertItems: [GridNodeInsertItem]
    let updateItems: [GridNodeUpdateItem]
    let scrollToItem: GridNodeScrollToItem?
    let stationaryItems: GridNodeStationaryItems
}

struct ChatHistoryViewTransitionInsertEntry {
    let index: Int
    let previousIndex: Int?
    let entry: ChatHistoryEntry
    let directionHint: ListViewItemOperationDirectionHint?
}

struct ChatHistoryViewTransitionUpdateEntry {
    let index: Int
    let previousIndex: Int
    let entry: ChatHistoryEntry
    let directionHint: ListViewItemOperationDirectionHint?
}

private func mappedInsertEntries(context: AccountContext, peerId: PeerId, controllerInteraction: ChatInteraction, entries: [ChatHistoryViewTransitionInsertEntry]) -> [GridNodeInsertItem] {
    return entries.map { entry -> GridNodeInsertItem in
        switch entry.entry {
        case let .MessageEntry(message, _, _, _, _, _, _, _, _):
            return GridNodeInsertItem(index: entry.index, item: GridMessageItem(context: context, message: message, chatInteraction: controllerInteraction), previousIndex: entry.previousIndex)
        case .HoleEntry:
            return GridNodeInsertItem(index: entry.index, item: GridHoleItem(), previousIndex: entry.previousIndex)
        case .UnreadEntry:
            assertionFailure()
            return GridNodeInsertItem(index: entry.index, item: GridHoleItem(), previousIndex: entry.previousIndex)
        default:
            return GridNodeInsertItem(index: entry.index, item: GridHoleItem(), previousIndex: entry.previousIndex)
        }
    }
}

private func mappedUpdateEntries(context: AccountContext, peerId: PeerId, controllerInteraction: ChatInteraction, entries: [ChatHistoryViewTransitionUpdateEntry]) -> [GridNodeUpdateItem] {
    return entries.map { entry -> GridNodeUpdateItem in
        switch entry.entry {
        case let .MessageEntry(message, _, _, _, _, _, _, _, _):
            return GridNodeUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: GridMessageItem(context: context, message: message, chatInteraction: controllerInteraction))
        case .HoleEntry:
            return GridNodeUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: GridHoleItem())
        case .UnreadEntry:
            assertionFailure()
            return GridNodeUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: GridHoleItem())
        default:
            assertionFailure()
            return GridNodeUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: GridHoleItem())
        }
    }
}

private func mappedChatHistoryViewListTransition(context: AccountContext, peerId: PeerId, controllerInteraction: ChatInteraction, transition: ChatHistoryViewTransition, from: ChatHistoryView?) -> ChatHistoryGridViewTransition {
    var mappedScrollToItem: GridNodeScrollToItem?
    if let scrollToItem = transition.scrollToItem {
        let mappedPosition: GridNodeScrollToItemPosition
        switch scrollToItem.position {
        case .Top:
            mappedPosition = .top
        case .Center:
            mappedPosition = .center
        case .Bottom:
            mappedPosition = .bottom
        }
        let scrollTransition: ContainedViewLayoutTransition
        if scrollToItem.animated {
            switch scrollToItem.curve {
            case .Default:
                scrollTransition = .animated(duration: 0.3, curve: .easeInOut)
            case let .Spring(duration):
                scrollTransition = .animated(duration: duration, curve: .spring)
            }
        } else {
            scrollTransition = .immediate
        }
        let directionHint: GridNodePreviousItemsTransitionDirectionHint
        switch scrollToItem.directionHint {
        case .Up:
            directionHint = .up
        case .Down:
            directionHint = .down
        }
        mappedScrollToItem = GridNodeScrollToItem(index: scrollToItem.index, position: mappedPosition, transition: scrollTransition, directionHint: directionHint, adjustForSection: true, adjustForTopInset: true)
    }
    
    var stationaryItems: GridNodeStationaryItems = .none
    if let previousView = from {
        if let stationaryRange = transition.stationaryItemRange {
            var fromStableIds = Set<ChatHistoryEntryId>()
            for i in 0 ..< previousView.filteredEntries.count {
                if i >= stationaryRange.0 && i <= stationaryRange.1 {
                    fromStableIds.insert(previousView.filteredEntries[i].entry.stableId)
                }
            }
            var index = 0
            var indices = Set<Int>()
            for entry in transition.historyView.filteredEntries {
                if fromStableIds.contains(entry.entry.stableId) {
                    indices.insert(transition.historyView.filteredEntries.count - 1 - index)
                }
                index += 1
            }
            stationaryItems = .indices(indices)
        } else {
            var fromStableIds = Set<ChatHistoryEntryId>()
            for i in 0 ..< previousView.filteredEntries.count {
                fromStableIds.insert(previousView.filteredEntries[i].entry.stableId)
            }
            var index = 0
            var indices = Set<Int>()
            for entry in transition.historyView.filteredEntries {
                if fromStableIds.contains(entry.entry.stableId) {
                    indices.insert(transition.historyView.filteredEntries.count - 1 - index)
                }
                index += 1
            }
            stationaryItems = .indices(indices)
        }
    }
    

    return ChatHistoryGridViewTransition(historyView: transition.historyView, topOffsetWithinMonth: 0, deleteItems: transition.deleteItems.map { $0.index }, insertItems: mappedInsertEntries(context: context, peerId: peerId, controllerInteraction: controllerInteraction, entries: transition.insertEntries), updateItems: mappedUpdateEntries(context: context, peerId: peerId, controllerInteraction: controllerInteraction, entries: transition.updateEntries), scrollToItem: mappedScrollToItem, stationaryItems: stationaryItems)
}




private func mappedInsertEntries(context: AccountContext, chatInteraction: ChatInteraction, entries: [(Int,ChatHistoryEntry,Int?)]) -> [GridNodeInsertItem] {
    return entries.map { entry -> GridNodeInsertItem in
        switch entry.1 {
        case let .MessageEntry(message, _, _, _, _, _, _, _, _):
            return GridNodeInsertItem(index: entry.0, item: GridMessageItem(context: context, message: message, chatInteraction: chatInteraction), previousIndex: entry.2)
        case .HoleEntry:
            return GridNodeInsertItem(index: entry.0, item: GridHoleItem(), previousIndex: entry.2)
        case .UnreadEntry:
            assertionFailure()
            return GridNodeInsertItem(index: entry.0, item: GridHoleItem(), previousIndex: entry.2)
        case .DateEntry:
             return GridNodeInsertItem(index: entry.0, item: GridHoleItem(), previousIndex: entry.2)
        default:
            fatalError()
        }
    }
}

private func mappedUpdateEntries(context: AccountContext, chatInteraction: ChatInteraction, entries: [(Int,ChatHistoryEntry,Int)]) -> [GridNodeUpdateItem] {
    return entries.map { entry -> GridNodeUpdateItem in
        switch entry.1 {
        case let .MessageEntry(message, _, _, _, _, _, _, _, _):
            return GridNodeUpdateItem(index: entry.0, previousIndex: entry.2, item: GridMessageItem(context: context, message: message, chatInteraction: chatInteraction))
        case .HoleEntry:
            return GridNodeUpdateItem(index: entry.0, previousIndex: entry.2, item: GridHoleItem())
        case .UnreadEntry:
            assertionFailure()
            return GridNodeUpdateItem(index: entry.0, previousIndex: entry.2, item: GridHoleItem())
        case .DateEntry:
            return GridNodeUpdateItem(index: entry.0, previousIndex: entry.2, item: GridHoleItem())
        default:
            fatalError()
        }
    }
}



private func itemSizeForContainerLayout(size: CGSize) -> CGSize {
    let side = floor(size.width / 4.0)
    return CGSize(width: side, height: side)
}

class PeerMediaGridView : View {
    let grid:GridNode
    var emptyView:PeerMediaEmptyRowView
    var emptyItem:PeerMediaEmptyRowItem = PeerMediaEmptyRowItem(NSZeroSize, tags: .photoOrVideo)
    required init(frame frameRect: NSRect) {
        grid = GridNode(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height))
        emptyView = PeerMediaEmptyRowView(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height))
        emptyView.set(item: emptyItem, animated: false)
        super.init(frame: frameRect)
        addSubview(grid)
        addSubview(emptyView)
        update(hasEntities: true)
    }
    
    func update(hasEntities: Bool) {
        grid.isHidden = !hasEntities
        emptyView.isHidden = hasEntities
    }
    
    override func layout() {
        super.layout()
        grid.frame = bounds
        emptyView.frame = bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class PeerMediaGridController: GenericViewController<PeerMediaGridView> {
    
    private let context: AccountContext
    private let chatLocation: ChatLocation
    private let messageId: MessageId?
    private let tagMask: MessageTags?
    private let previousView = Atomic<ChatHistoryView?>(value: nil)
    private let chatInteraction: ChatInteraction
    public let historyState = ValuePromise<ChatHistoryNodeHistoryState>()
    private var currentHistoryState: ChatHistoryNodeHistoryState?
    private var enqueuedHistoryViewTransition: (ChatHistoryGridViewTransition, () -> Void)?
    var layoutActionOnViewTransition: ((ChatHistoryGridViewTransition) -> (ChatHistoryGridViewTransition, ListViewUpdateSizeAndInsets?))?

    private var historyView: ChatHistoryView?

    private let historyDisposable = MetaDisposable()
    
    private let _chatHistoryLocation = ValuePromise<ChatHistoryLocation>(ignoreRepeated: true)
    private var chatHistoryLocation: Signal<ChatHistoryLocation, NoError> {
        return self._chatHistoryLocation.get()
    }
    
    
    private var screenCount:Int {
        let screenCount = (frame.width / 100) * (frame.height / 100)
        return Int(screenCount * 4)
    }
    
    private var requestCount:Int  = 0
    
    func enableScroll() -> Void {
        
        genericView.grid.scrollHandler = { [weak self] scroll in
            guard let view = self?.historyView?.originalView else {return}
            guard let `self` = self else {return}

            var index:MessageIndex?
            switch scroll.direction {
            case .bottom:
                index = view.earlierId
            case .top:
                index = view.laterId
            default:
                break
            }
            if let index = index {
                let location = ChatHistoryLocation.Navigation(index: MessageHistoryAnchorIndex.message(index), anchorIndex: view.anchorIndex, count: self.requestCount + self.screenCount, side: scroll.direction == .bottom ? .lower : .upper)
                
                self.disableScroll()
                
                self._chatHistoryLocation.set(location)
            }
            
        }
    }
    
    func disableScroll() -> Void {
        genericView.grid.visibleItemsUpdated = nil
        genericView.grid.scrollHandler = {_ in}
    }
    
    var itemSize: NSSize {
        let count = ceil(bounds.width / 120)
        let width = floorToScreenPixels(scaleFactor: view.backingScaleFactor, bounds.width / count)
        return NSMakeSize(width - 4, width)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        genericView.grid.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: CGSize(width: frame.width, height: frame.height), insets: NSEdgeInsets(), preloadSize: self.bounds.width, type: .fixed(itemSize: itemSize, lineSpacing: 4)), transition: .immediate), itemTransition: .immediate, stationaryItems: .all, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        
        self._chatHistoryLocation.set(ChatHistoryLocation.Initial(count: screenCount))
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        
        enum MultipleSelectionState {
            case none
            case select
            case deselect
        }
        
        var selectionState: MultipleSelectionState = .none
        
        window?.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            guard let `self` = self, !hasModals() else {return .rejected}
            let viewPoint = self.genericView.convert(event.locationInWindow, from: nil)
            
            if self.chatInteraction.presentation.state == .selecting, viewPoint.y < self.genericView.frame.height - 50 {
                let point = self.genericView.grid.documentView!.convert(event.locationInWindow, from: nil)
                let view = self.genericView.grid.itemNodeAtPoint(point) as? GridMessageItemNode
                if let message = view?.message {
                    if self.chatInteraction.presentation.isSelectedMessageId(message.id) {
                        selectionState = .deselect
                        self.chatInteraction.update({$0.withRemovedSelectedMessage(message.id)})
                    } else {
                        selectionState = .select
                        self.chatInteraction.update({$0.withUpdatedSelectedMessage(message.id)})
                    }
                    view?.updateSelectionState(animated: true)
                    return .invoked
                } else {
                    selectionState = .none
                }
            } else {
                selectionState = .none
            }
            
            return .rejected
        }, with: self, for: .leftMouseDown)
        
        window?.set(mouseHandler: { event -> KeyHandlerResult in
            if hasModals() {
                return .rejected
            }
            let _selectionState = selectionState
            selectionState = .none
            switch _selectionState {
            case .select:
                return .invoked
            case .deselect:
                return .invoked
            case .none:
                return .rejected
            }
        }, with: self, for: .leftMouseUp)
        
        window?.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}

            
            let point = self.genericView.grid.documentView!.convert(event.locationInWindow, from: nil)
            let view = self.genericView.grid.itemNodeAtPoint(point) as? GridMessageItemNode
            if let message = view?.message {
                switch selectionState {
                case .select:
                    self.chatInteraction.update({$0.withUpdatedSelectedMessage(message.id)})
                    view?.updateSelectionState(animated: true)
                    return .invoked
                case .deselect:
                    self.chatInteraction.update({$0.withRemovedSelectedMessage(message.id)})
                    view?.updateSelectionState(animated: true)
                    return .invoked
                case .none:
                    break
                }
            }
           
            
            return .rejected
        }, with: self, for: .leftMouseDragged)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        window?.removeAllHandlers(for: self)
    }
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        genericView.grid.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: CGSize(width: frame.width, height: frame.height), insets: NSEdgeInsets(), preloadSize: self.bounds.width, type: .fixed(itemSize: itemSize, lineSpacing: 4)), transition: .immediate), itemTransition: .immediate, stationaryItems: .all, updateFirstIndexInSectionOffset: nil), completion: { _ in })
    }
    
  
    
    public init(context: AccountContext, chatLocation: ChatLocation, messageId: MessageId?, tagMask: MessageTags?, chatInteraction: ChatInteraction) {
        self.context = context
        self.chatLocation = chatLocation
        self.messageId = messageId
        self.tagMask = tagMask
        self.chatInteraction = chatInteraction
        super.init()
        
        let historyViewUpdate = self.chatHistoryLocation
            |> distinctUntilChanged |> beforeNext { [weak self] location -> ChatHistoryLocation in
                self?.requestCount += location.count
                return location
            }
            |> mapToSignal { (location) in
                return chatHistoryViewForLocation(location, account: context.account, chatLocation: chatLocation, fixedCombinedReadStates: nil, tagMask: tagMask)
            }
        
        let previousView = self.previousView
        
        let historyViewTransition = combineLatest(historyViewUpdate, appearanceSignal) |> mapToQueue { [weak self] update, appearance -> Signal<ChatHistoryGridViewTransition, NoError> in
            switch update {
            case .Loading:
                Queue.mainQueue().async { [weak self] in
                    if let strongSelf = self {
                        let historyState: ChatHistoryNodeHistoryState = .loading
                        if strongSelf.currentHistoryState != historyState {
                            strongSelf.currentHistoryState = historyState
                            strongSelf.historyState.set(historyState)
                        }
                    }
                }
                return .complete()
            case let .HistoryView(view, type, _, _):
                let reason: ChatHistoryViewTransitionReason
                var prepareOnMainQueue = false
                switch type {
                case let .Initial(fadeIn):
                    reason = ChatHistoryViewTransitionReason.Initial(fadeIn: fadeIn)
                    prepareOnMainQueue = !fadeIn
                case let .Generic(genericType):
                    switch genericType {
                    case .InitialUnread:
                        reason = ChatHistoryViewTransitionReason.Initial(fadeIn: false)
                    case .Generic:
                        reason = ChatHistoryViewTransitionReason.InteractiveChanges
                    case .UpdateVisible:
                        reason = ChatHistoryViewTransitionReason.Reload
                    case let .FillHole(insertions, deletions):
                        reason = ChatHistoryViewTransitionReason.HoleChanges(filledHoleDirections: insertions, removeHoleDirections: deletions)
                    }
                }
                
                let entries = messageEntries(view.entries).map({ChatWrapperEntry(appearance: AppearanceWrapperEntry(entry: $0, appearance: appearance), automaticDownload: AutomaticMediaDownloadSettings.defaultSettings)})
                
                let processedView = ChatHistoryView(originalView: view, filteredEntries: entries)
                let previous = previousView.swap(processedView)
                
     
                
                
                return preparedChatHistoryViewTransition(from: previous, to: processedView, reason: reason, account: context.account, peerId: chatInteraction.peerId, controllerInteraction: chatInteraction, scrollPosition: nil, initialData: nil, keyboardButtonsMessage: nil, cachedData: nil) |> map({ mappedChatHistoryViewListTransition(context: context, peerId: chatInteraction.peerId, controllerInteraction: chatInteraction, transition: $0, from: previous) }) |> runOn(prepareOnMainQueue ? Queue.mainQueue() : prepareQueue)
            }
        }
        
        let appliedTransition = historyViewTransition |> deliverOnMainQueue |> mapToQueue { [weak self] transition -> Signal<Void, NoError> in
            if let strongSelf = self {
                return strongSelf.enqueueHistoryViewTransition(transition)
            }
            return .complete()
        }
        
        self.historyDisposable.set(appliedTransition.start())
        
        
        
        
    }
    
    
    
    
    private func dequeueHistoryViewTransition() {
        readyOnce()
        if let (transition, completion) = self.enqueuedHistoryViewTransition {
            self.enqueuedHistoryViewTransition = nil
            
            let completion: (GridNodeDisplayedItemRange) -> Void = { [weak self] visibleRange in
                if let strongSelf = self, let view = transition.historyView.originalView {
                    strongSelf.historyView = transition.historyView
                    
                    if let range = visibleRange.loadedRange {
                        strongSelf.context.account.postbox.updateMessageHistoryViewVisibleRange(view.id, earliestVisibleIndex: transition.historyView.filteredEntries[transition.historyView.filteredEntries.count - 1 - range.upperBound].entry.index, latestVisibleIndex: transition.historyView.filteredEntries[transition.historyView.filteredEntries.count - 1 - range.lowerBound].entry.index)
                    }
                    
                    let historyState: ChatHistoryNodeHistoryState = .loaded(isEmpty: view.entries.isEmpty)
                    if strongSelf.currentHistoryState != historyState {
                        strongSelf.currentHistoryState = historyState
                        strongSelf.historyState.set(historyState)
                    }
                    
                    completion()
                }
            }
            
            let updateLayout = GridNodeUpdateLayout(layout: GridNodeLayout(size: CGSize(width: frame.width, height: frame.height), insets: NSEdgeInsets(), preloadSize: self.frame.width, type: .fixed(itemSize: self.itemSize, lineSpacing: 4)), transition: .immediate)
            
            self.genericView.grid.transaction(GridNodeTransaction(deleteItems: transition.deleteItems, insertItems: transition.insertItems, updateItems: transition.updateItems, scrollToItem: transition.scrollToItem, updateLayout: updateLayout, itemTransition: .immediate, stationaryItems: transition.stationaryItems, updateFirstIndexInSectionOffset: transition.topOffsetWithinMonth), completion: completion)
            
            genericView.update(hasEntities: !genericView.grid.isEmpty)
        }
    }
    
    private func enqueueHistoryViewTransition(_ transition: ChatHistoryGridViewTransition) -> Signal<Void, NoError> {
        return Signal { [weak self] subscriber in
            
            if let strongSelf = self {
                if let _ = strongSelf.enqueuedHistoryViewTransition {
                    preconditionFailure()
                }
                
                strongSelf.enqueuedHistoryViewTransition = (transition, {
                    subscriber.putCompletion()
                })
                
                strongSelf.dequeueHistoryViewTransition()
                
                strongSelf.enableScroll()

            } else {
                subscriber.putCompletion()
            }
            
            return EmptyDisposable
            
        } |> runOn(Queue.mainQueue())
    }
    
    deinit {
        self.historyDisposable.dispose()
    }
    
}
