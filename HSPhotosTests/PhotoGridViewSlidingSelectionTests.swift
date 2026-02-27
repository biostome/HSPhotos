import XCTest
import Testing
import Photos

class PhotoGridViewSlidingSelectionTests: XCTestCase{
    
    // 测试滑动选择算法
    func testSlidingSelectionAlgorithm() {
        // 测试从(1-1)滑动到(1-3) - 同一行内滑动
        let start1 = IndexPath(item: 0, section: 0) // (1-1)
        let end1 = IndexPath(item: 2, section: 0) // (1-3)
        let result1 = calculateSelectionArea(start: start1, end: end1, itemsPerSection: 5)
        XCTAssertEqual(result1.count, 3, "从(1-1)到(1-3)应该选择3个")
        
        // 测试从(1-3)滑动回(1-2) - 同一行内滑动
        let start2 = IndexPath(item: 0, section: 0) // (1-1)
        let end2 = IndexPath(item: 1, section: 0) // (1-2)
        let result2 = calculateSelectionArea(start: start2, end: end2, itemsPerSection: 5)
        XCTAssertEqual(result2.count, 2, "从(1-1)到(1-2)应该选择2个")
        
        // 测试从(1-2)滑动到(1-4) - 同一行内滑动
        let start3 = IndexPath(item: 0, section: 0) // (1-1)
        let end3 = IndexPath(item: 3, section: 0) // (1-4)
        let result3 = calculateSelectionArea(start: start3, end: end3, itemsPerSection: 5)
        XCTAssertEqual(result3.count, 4, "从(1-1)到(1-4)应该选择4个")
        
        // 测试从(1-4)滑动到(2-4) - 跨两行滑动
        // 选择区域：第1行(1-1到1-5)、第2行(2-1到2-4)
        let start4 = IndexPath(item: 0, section: 0) // (1-1)
        let end4 = IndexPath(item: 3, section: 1) // (2-4)
        let result4 = calculateSelectionArea(start: start4, end: end4, itemsPerSection: 5)
        XCTAssertEqual(result4.count, 9, "从(1-1)到(2-4)应该选择9个")
        
        // 测试从(2-4)滑动到(3-4) - 跨三行滑动
        // 选择区域：第1行(1-1到1-5)、第2行整行、第3行(3-1到3-4)
        let start5 = IndexPath(item: 0, section: 0) // (1-1)
        let end5 = IndexPath(item: 3, section: 2) // (3-4)
        let result5 = calculateSelectionArea(start: start5, end: end5, itemsPerSection: 5)
        XCTAssertEqual(result5.count, 14, "从(1-1)到(3-4)应该选择14个")
        
        // 测试从(3-4)滑动回(2-4) - 跨两行滑动
        // 选择区域：第1行(1-1到1-5)、第2行(2-1到2-4)
        let start6 = IndexPath(item: 0, section: 0) // (1-1)
        let end6 = IndexPath(item: 3, section: 1) // (2-4)
        let result6 = calculateSelectionArea(start: start6, end: end6, itemsPerSection: 5)
        XCTAssertEqual(result6.count, 9, "从(1-1)到(2-4)应该选择9个")
        
        // 测试从(1-1)滑动到(2-5) - 跨两行滑动
        // 选择区域：第1行(1-1到1-5)、第2行整行
        let start7 = IndexPath(item: 0, section: 0) // (1-1)
        let end7 = IndexPath(item: 4, section: 1) // (2-5)
        let result7 = calculateSelectionArea(start: start7, end: end7, itemsPerSection: 5)
        XCTAssertEqual(result7.count, 10, "从(1-1)到(2-5)应该选择10个")
        
        // 测试反向选择 - 从(1-3)滑动到(1-1)
        let start8 = IndexPath(item: 2, section: 0) // (1-3)
        let end8 = IndexPath(item: 0, section: 0) // (1-1)
        let result8 = calculateSelectionArea(start: start8, end: end8, itemsPerSection: 5)
        XCTAssertEqual(result8.count, 3, "从(1-3)到(1-1)应该选择3个")
        
        // 测试反向选择 - 从(2-4)滑动到(1-1)
        let start9 = IndexPath(item: 3, section: 1) // (2-4)
        let end9 = IndexPath(item: 0, section: 0) // (1-1)
        let result9 = calculateSelectionArea(start: start9, end: end9, itemsPerSection: 5)
        XCTAssertEqual(result9.count, 9, "从(2-4)到(1-1)应该选择9个")
        
        // 测试反向选择 - 从(3-4)滑动到(1-1)
        let start10 = IndexPath(item: 3, section: 2) // (3-4)
        let end10 = IndexPath(item: 0, section: 0) // (1-1)
        let result10 = calculateSelectionArea(start: start10, end: end10, itemsPerSection: 5)
        XCTAssertEqual(result10.count, 14, "从(3-4)到(1-1)应该选择14个")
    }
    
    // 计算选择区域
    func calculateSelectionArea(start: IndexPath, end: IndexPath, itemsPerSection: Int) -> [IndexPath] {
        // 计算矩形选择区域
        let minItem = min(start.item, end.item)
        let maxItem = max(start.item, end.item)
        let minSection = min(start.section, end.section)
        let maxSection = max(start.section, end.section)
        
        // 收集所有需要更新的索引路径
        var indexPathsToUpdate: [IndexPath] = []
        
        // 遍历矩形区域内的所有单元格
        for section in minSection...maxSection {
            var sectionStartItem = minItem
            var sectionEndItem = maxItem
            
            // 对于同一行内的滑动，只选择从起始位置到结束位置的照片
            if minSection == maxSection {
                sectionStartItem = minItem
                sectionEndItem = maxItem
            } else {
                // 对于跨多行的滑动：
                // 起始行：从起始位置到行尾
                // 中间行：整行
                // 结束行：从行首到结束位置
                if section == minSection {
                    // 起始行：从起始位置到行尾
                    sectionEndItem = itemsPerSection - 1
                } else if section == maxSection {
                    // 结束行：从行首到结束位置
                    sectionStartItem = 0
                } else {
                    // 中间行：整行
                    sectionStartItem = 0
                    sectionEndItem = itemsPerSection - 1
                }
            }
            
            for item in sectionStartItem...sectionEndItem {
                if item < itemsPerSection {
                    let currentIndexPath = IndexPath(item: item, section: section)
                    indexPathsToUpdate.append(currentIndexPath)
                }
            }
        }
        
        return indexPathsToUpdate
    }
    
    // 测试选择模式逻辑
    func testSelectionModeLogic() {
        // 测试选中模式：起点未选中
        let startIndexPath = IndexPath(item: 0, section: 0) // (1-1)
        let endIndexPath = IndexPath(item: 2, section: 0) // (1-3)
        let selectionArea = calculateSelectionArea(start: startIndexPath, end: endIndexPath, itemsPerSection: 5)
        
        // 验证选择区域大小
        XCTAssertEqual(selectionArea.count, 3, "选择区域大小应该为3")
        
        // 验证选择区域包含正确的索引路径
        XCTAssertTrue(selectionArea.contains(IndexPath(item: 0, section: 0)), "选择区域应该包含(1-1)")
        XCTAssertTrue(selectionArea.contains(IndexPath(item: 1, section: 0)), "选择区域应该包含(1-2)")
        XCTAssertTrue(selectionArea.contains(IndexPath(item: 2, section: 0)), "选择区域应该包含(1-3)")
    }
    
    // 测试边界情况
    func testBoundaryCases() {
        // 测试滑动到网格边缘
        let startIndexPath = IndexPath(item: 0, section: 0) // (1-1)
        let endIndexPath = IndexPath(item: 4, section: 4) // (5-5)
        let selectionArea = calculateSelectionArea(start: startIndexPath, end: endIndexPath, itemsPerSection: 5)
        
        // 验证选择区域大小
        XCTAssertEqual(selectionArea.count, 25, "选择区域大小应该为25")
        
        // 测试同一个单元格
        let startIndexPath2 = IndexPath(item: 0, section: 0) // (1-1)
        let endIndexPath2 = IndexPath(item: 0, section: 0) // (1-1)
        let selectionArea2 = calculateSelectionArea(start: startIndexPath2, end: endIndexPath2, itemsPerSection: 5)
        
        // 验证选择区域大小
        XCTAssertEqual(selectionArea2.count, 1, "选择区域大小应该为1")
    }
}
