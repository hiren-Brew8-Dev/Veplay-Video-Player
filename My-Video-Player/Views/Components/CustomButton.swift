//
//  CustomButton.swift
//  My-Video-Player
//
//  Created by Shivshankar T Tiwari on 16/02/26.
//

import Foundation
import SwiftUI

struct CustomButton: View {
    
    var title : String?
    var color : Color = .blue
    var image : ImageResource? = nil
    var width : CGFloat = 25
    var fontSize : CGFloat = 18
    let action : () -> Void
    
    var body: some View {
        Button {
            
            action()
        } label: {
            ZStack {
                if let image = image {
                    Image(image)
                        .resizable()
                        .scaledToFit()
                        .responsiveWidth(iphoneWidth: width, ipadWidth: width)
                }
                
                if title != nil {
                    Text(title ?? "")
                        .foregroundStyle(color)
                        
                }
            }
        }
        .buttonStyle(.plain)
    }
}
