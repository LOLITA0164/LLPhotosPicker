//
//  LLImagePickerCtrl.swift
//  LLImagePicker
//
//  Created by LOLITA on 2019/4/14.
//  Copyright © 2019 LOLITA0164. All rights reserved.
//

import UIKit
import Photos

// 相簿列表项
struct LLImageAlbumItem {
    // 相簿名称
    var title:String?
    // 相簿内的资源
    var fetchResult:PHFetchResult<PHAsset>
}

class LLImagePickerCtrl: UIViewController {
    
    // 显示相簿列表项的表格
    @IBOutlet weak var tableView: UITableView!
    // 相簿列表项集合
    var items:[LLImageAlbumItem] = []
    
    // 每次最多可选择的照片数量
    var maxSelected:Int = Int.max
    
    // 照片选择完毕后的回调
    public typealias handler = (_ assets:[PHAsset])->Void
    var completeHandler:handler?
    
    
    // 从xib或者storyboard加载完毕就会调用
    override func awakeFromNib() {
        super.awakeFromNib()
        // 获取相册数据
        self.requestAlbums()
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupUI()
    }
    
    /// 设置UI
    private func setupUI() {
        self.title = "相簿"
        // 设置表格的相关样式属性
        self.tableView.separatorInset = UIEdgeInsets.init(top: 0, left: 0, bottom: 0, right: 0)
        self.tableView.rowHeight = 58
        self.tableView.tableFooterView = UIView()
        // 设置导航右侧的取消按钮
        let rightBarItem = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(self.cancel))
        self.navigationItem.rightBarButtonItem = rightBarItem
    }
    
    /// 获取相册数据
    private func requestAlbums() {
        // 申请读取相册权限
        PHPhotoLibrary.requestAuthorization { (status) in
            guard status == .authorized else {
                // 设置开通相册权限的 UI
                // MARK:- 设置开通相册权限的 UI 【未完成】
                
                return
            }
            
            // 列出所有系统的智能相册
            let smartOptions = PHFetchOptions()
            let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .albumRegular, options: smartOptions)
            self.convertCollection(collection: smartAlbums)
            
            // 列出所有用户创建的相册
            let userCollections = PHCollectionList.fetchTopLevelUserCollections(with: nil)
            self.convertCollection(collection: userCollections as! PHFetchResult<PHAssetCollection>)
            
            // 相册按照包含的图片数量进行降序
            self.items.sort(by: { (obj1, obj2) -> Bool in
                return obj1.fetchResult.count > obj2.fetchResult.count
            })
            
            // 在主线程中刷新数据
            DispatchQueue.main.async {
                self.tableView.reloadData()
                
                // 首次进入后直接进入到第一个相册图片展示页面
                if let imageCollectionCtrl = self.storyboard?.instantiateViewController(withIdentifier: "LLImageCollectionCtrl") as? LLImageCollectionCtrl {
                    imageCollectionCtrl.title = self.items.first?.title
                    imageCollectionCtrl.assetsFetchResults = self.items.first?.fetchResult
                    imageCollectionCtrl.completeHandler = self.completeHandler
                    imageCollectionCtrl.maxCount = self.maxSelected
                    self.navigationController?.pushViewController(imageCollectionCtrl, animated: false)
                }
            }
        }
    }
    
    // 转化处理获取到的相簿
    private func convertCollection(collection:PHFetchResult<PHAssetCollection>) {
        for i in 0..<collection.count {
            // 获取出当前相簿内的图片
            let resultsOptions = PHFetchOptions()
            resultsOptions.sortDescriptors = [NSSortDescriptor.init(key: "creationDate", ascending: false)]
//            resultsOptions.predicate = NSPredicate.init(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
            let c = collection[i]
            let assetsFetchResult = PHAsset.fetchAssets(in: c, options: resultsOptions)
            // 没有找到图片的空相簿不显示
            if assetsFetchResult.count > 0 {
                let title = titleOfAlbumForChinse(title: c.localizedTitle)
                self.items.append(LLImageAlbumItem.init(title: title, fetchResult: assetsFetchResult))
            }
        }
    }
    
    
    /// 将系统返回的相册的英文名称转换为中文
    ///
    /// - Parameter title: 相簿名称
    /// - Returns: 转换后的相簿名称
    private func titleOfAlbumForChinse(title:String?) -> String? {
        let title_dic = [
            "Slo-mo":"慢动作",
            "Recently Added":"最近添加",
            "Favorites":"个人收藏",
            "Recently Deleted":"最近删除",
            "Videos":"视频",
            "All Photos":"所有照片",
            "Selfies":"自拍",
            "Screenshots":"屏幕快照",
            "Camera Roll":"相机胶卷",
            "Animated":"动图",
            "Hidden":"隐藏",
            "Panoramas":"全景"
        ]
        let tmp_title = title_dic[ title==nil ? "" : title! ]
        return tmp_title==nil ? title : tmp_title
    }

    // 取消事件
    @objc func cancel() {
        self.dismiss(animated: true, completion: nil)
    }
    
    // 页面的跳转事件
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // 判断是否时跳转到缩略图集合页面
        if segue.identifier == "showImages" {
            // 获取到缩略图集合页面
            guard let imageCollectionCtrl = segue.destination as? LLImageCollectionCtrl, let cell = sender as? LLImagePickerCell else {
                return
            }
            // 设置回调函数
            imageCollectionCtrl.completeHandler = self.completeHandler
            // 设置标题
            imageCollectionCtrl.title = cell.titleLabel.text
            // 设置最多可选择图片的数量
            imageCollectionCtrl.maxCount = self.maxSelected
            guard let indexPath = self.tableView.indexPath(for: cell) else { return }
            // 获取到选中相簿信息
            let fetchResult = self.items[indexPath.row].fetchResult
            // 将相簿内的图片资源传递过去
            imageCollectionCtrl.assetsFetchResults = fetchResult
         }
    }
}


// 相簿列表页面的UITableViewDelegate、UITableViewDataSource协议方法
extension LLImagePickerCtrl:UITableViewDelegate,UITableViewDataSource {
    // 设置单元格数量
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.items.count
    }
    // 设置单元格内容
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // 同一形式的单元格重复使用，在声明时候已经注册
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! LLImagePickerCell
        let item = self.items[indexPath.row]
        cell.titleLabel.text = item.title
        cell.countLabel.text = "（" + String(item.fetchResult.count) + "）"
        return cell
    }
    // 表格单元格选中事件
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// 该类暴露给外部调用的接口
extension UIViewController {
    
    /// 显示图片选取器
    ///
    /// - Parameters:
    ///   - maxCount: 选择的最大数量
    ///   - completeHandler: 完成回调
    /// - Returns: 返回当前图片选取器
    func presentLLImagePicker(maxCount:Int=Int.max, completeHandler:LLImagePickerCtrl.handler?) -> LLImagePickerCtrl? {
        // 获取到storyboard中的控制器
        if let ctrl = UIStoryboard.init(name: "LLImage", bundle: Bundle.main).instantiateViewController(withIdentifier: "imagePickerCtrl") as? LLImagePickerCtrl {
            // 设置选择完毕后的回调
            ctrl.completeHandler = completeHandler
            // 设置图片选择的最大数量
            ctrl.maxSelected = maxCount
            // 将图片选择视图控制器套上一个导航控制器
            let nav = UINavigationController.init(rootViewController: ctrl)
            nav.navigationBar.isTranslucent = false
            self.present(nav, animated: true, completion: nil)
            return ctrl
        }
        return nil
    }
}