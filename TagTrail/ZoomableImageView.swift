//
//  ZoomableImageView.swift
//  TagTrail
//
//  Created by Priyanshu Rastogi on 2025-08-08.
//

import SwiftUI
import UIKit
import ImageIO

struct ZoomableImageView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 6.0
        scrollView.bouncesZoom = true
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .black

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.tintColor = .white
        imageView.backgroundColor = .black

        let screen = UIScreen.main.bounds.size
        imageView.image = downsample(imageAt: url, to: screen, scale: UIScreen.main.scale)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        // Close button
        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        close.tintColor = .white
        close.translatesAutoresizingMaskIntoConstraints = false
        close.addAction(UIAction { _ in
            scrollView.findViewController()?.dismiss(animated: true)
        }, for: .primaryActionTriggered)
        scrollView.addSubview(close)
        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: scrollView.safeAreaLayoutGuide.topAnchor, constant: 8),
            close.trailingAnchor.constraint(equalTo: scrollView.safeAreaLayoutGuide.trailingAnchor, constant: -8)
        ])

        context.coordinator.imageView = imageView
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) { }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let view = imageView else { return }
            let offsetX = max((scrollView.bounds.size.width - view.frame.size.width) * 0.5, 0)
            let offsetY = max((scrollView.bounds.size.height - view.frame.size.height) * 0.5, 0)
            view.center = CGPoint(
                x: scrollView.bounds.midX + offsetX - scrollView.contentInset.right + scrollView.contentInset.left,
                y: scrollView.bounds.midY + offsetY - scrollView.contentInset.bottom + scrollView.contentInset.top
            )
        }
    }
}

// MARK: - Helpers

func downsample(imageAt imageURL: URL, to pointSize: CGSize, scale: CGFloat) -> UIImage? {
    let srcOpts = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, srcOpts) else { return nil }
    let maxPixels = max(pointSize.width, pointSize.height) * scale
    let opts = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixels
    ] as CFDictionary
    guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, opts) else { return nil }
    return UIImage(cgImage: cg)
}

extension UIView {
    func findViewController() -> UIViewController? {
        sequence(first: self.next, next: { $0?.next })
            .first { $0 is UIViewController } as? UIViewController
    }
}
