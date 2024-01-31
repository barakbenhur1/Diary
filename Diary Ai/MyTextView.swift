//
//  MyTextView.swift
//  AR
//
//  Created by Barak Ben Hur on 27/01/2024.
//

import UIKit
import SnapKit

class MyTextView: UITextView {
    private let ph = UILabel()
    
    var feel = ""
    
    var original = ""
    
    private var textViewDidChange: (String) -> () = { text in }
    
    init(placeHolder: String) {
        super.init(frame: .zero, textContainer: nil)
        
        delegate = self
        
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        
        backgroundColor = .clear
        
        ph.backgroundColor = .clear
        
        ph.textColor = .lightGray
        
        ph.text = placeHolder
        
        font = .systemFont(ofSize: 18)
        
        ph.font = font
        
        addSubview(ph)
        
        ph.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.bottom.equalToSuperview()
            make.leading.equalToSuperview().offset(3)
            make.trailing.equalToSuperview()
        }
    }
    
    func textViewDidChange(_ block: @escaping (String) -> ()) {
        textViewDidChange = block
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(string: String) {
        text = string
        ph.isHidden = !string.isEmpty
    }
}

extension MyTextView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        ph.isHidden = !textView.text.isEmpty
        original = textView.text
        textViewDidChange(textView.text)
    }
}
