//
//  Config.swift
//  V2rayU
//
//  Created by yanue on 2018/10/9.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import WebKit
import os.log

class ConfigWindowController: NSWindowController,NSWindowDelegate {
    var lastIndex:Int = 0
    override var windowNibName: String? {
        return "ConfigWindow" // no extension .xib here
    }
    let tableViewDragType: String = "ss.server.profile.data"

    @IBOutlet weak var errTip: NSTextField!
    
    // menu controller
    let menuController = (NSApplication.shared.delegate as? AppDelegate)?.statusMenu.delegate as! MenuController
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.window?.delegate = self

        self.serversTableView.delegate = self
        self.serversTableView.dataSource = self
        self.serversTableView.reloadData()
    }

    override func awakeFromNib() {
        serversTableView.registerForDraggedTypes([NSPasteboard.PasteboardType(rawValue: tableViewDragType)])
    }
    
    @IBOutlet weak var configText: NSTextView!
    @IBOutlet weak var serversTableView: NSTableView!
    @IBOutlet weak var addRemoveButton: NSSegmentedControl!

    @IBAction func addRemoveServer(_ sender: NSSegmentedCell) {
        // 0 add,1 remove
        let seg = addRemoveButton.indexOfSelectedItem

        switch seg {
                // add server config
        case 0:
            // add
            _ = V2rayServer.add()

            // reload data
            self.serversTableView.reloadData()
            // selected current row
            self.serversTableView.selectRowIndexes(NSIndexSet(index: V2rayServer.count() - 1) as IndexSet, byExtendingSelection: false)
            
            break

                // delete server config
        case 1:
            // get seleted index
            let idx = self.serversTableView.selectedRow

            // remove
            V2rayServer.remove(idx: idx)

            // reload
            self.serversTableView.reloadData()

            // selected prev row
            let cnt: Int = V2rayServer.count()
            var rowIndex: Int = idx - 1
            if rowIndex < 0 {
                rowIndex = cnt - 1
            }
            if rowIndex >= 0 {
                self.loadJsonFile(rowIndex: rowIndex)
            } else {
                self.serversTableView.becomeFirstResponder()
            }

            // refresh menu
            menuController.showServers()
            break
            
        // unknown action
        default:
            return
        }
    }

    func loadJsonFile(rowIndex:Int) {
        if rowIndex < 0 {
            return
        }
        
        let v2ray = V2rayServer.loadV2rayItem(idx: rowIndex)
        self.configText.string = v2ray?.json ?? ""
    }
    

    @IBAction func ok(_ sender: NSButton) {
        // todo save
        let text = self.configText.string

        // save
        V2rayServer.save(idx: self.serversTableView.selectedRow, jsonData: text)
        
        print("save ok fater")
        // refresh menu
        menuController.showServers()
    }

    @IBAction func cancel(_ sender: NSButton) {
        // self close
        self.close()
        // hide dock icon and close all opened windows
        NSApp.setActivationPolicy(.accessory)
    }

    @objc private func onDoubleClicked() {
        print("onDoubleClicked row \(serversTableView.clickedRow), col \(serversTableView.clickedColumn) clicked")
    }

    @objc private func onItemClicked() {
        print("row \(serversTableView.clickedRow), col \(serversTableView.clickedColumn) clicked")
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
//        NSApp.setActivationPolicy(.accessory)
        print("close1")
        self.close()
        NSApp.terminate(self)
        return true
    }
    
    func windowWillClose(_ notification: Notification) {
        // hide dock icon and close all opened windows
        print("close")
//        NSApp.setActivationPolicy(.accessory)
    }
}

// NSTableViewDataSource
extension ConfigWindowController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return V2rayServer.count()
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let tableViewData = V2rayServer.list()
        // set cell data
        return tableViewData[row].remark
    }
    
    // edit cell
    func tableView(_ tableView: NSTableView, setObjectValue: Any?, for forTableColumn: NSTableColumn?, row: Int) {
        guard let remark = setObjectValue as? String else {
            os_log("remark is nil")
            return
        }
        // edit
        V2rayServer.edit(rowIndex: row, remark: remark)
        tableView.reloadData()
    }
}

// NSTableViewDelegate
extension ConfigWindowController: NSTableViewDelegate {
    // Drag & Drop reorder rows
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: NSPasteboard.PasteboardType(rawValue: tableViewDragType))
        return item
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int
        , proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .above {
            return .move
        }
        return NSDragOperation()
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        var oldIndexes = [Int]()
        info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:], using: {
            (draggingItem: NSDraggingItem, idx: Int, stop: UnsafeMutablePointer<ObjCBool>) in
            if let str = (draggingItem.item as! NSPasteboardItem).string(forType: NSPasteboard.PasteboardType(rawValue: self.tableViewDragType)),
                let index = Int(str) {
                oldIndexes.append(index)
            }
        })

        var oldIndexOffset = 0
        var newIndexOffset = 0
        var oldIndexLast = 0
        var newIndexLast = 0

        // For simplicity, the code below uses `tableView.moveRowAtIndex` to move rows around directly.
        // You may want to move rows in your content array and then call `tableView.reloadData()` instead.
        for oldIndex in oldIndexes {
            if oldIndex < row {
                oldIndexLast = oldIndex + oldIndexOffset
                newIndexLast = row - 1
                oldIndexOffset -= 1
            } else {
                oldIndexLast = oldIndex
                newIndexLast = row + newIndexOffset
                newIndexOffset += 1
            }
        }
        
        // move
        V2rayServer.move(oldIndex: oldIndexLast, newIndex: newIndexLast)
        self.serversTableView.reloadData()
        self.serversTableView.selectRowIndexes(NSIndexSet(index: newIndexLast) as IndexSet, byExtendingSelection: false)

        return true
    }
    
    // For NSTableViewDelegate
    func tableViewSelectionDidChange(_ notification: Notification) {
        self.loadJsonFile(rowIndex: self.serversTableView.selectedRow)
    }
}
