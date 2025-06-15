//  UIImage+Resize.swift
//  BeMeChallenge
import UIKit

extension UIImage {
    /// 지정한 최대 픽셀 길이를 넘지 않도록 (긴 축 기준) 비율에 맞춰 리사이즈
    func resized(maxPixel: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxPixel else { return self }
        let scale = maxPixel / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
}
