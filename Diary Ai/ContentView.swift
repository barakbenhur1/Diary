//
//  ContentView.swift
//  AR
//
//  Created by Barak Ben Hur on 27/01/2024.
//

import SwiftUI
import ARKit
import CoreData
import Foundation
import SwiftSpeech

struct ContentView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    
    @FetchRequest(sortDescriptors: []) var items: FetchedResults<EntryItem>
    
    @State private var itemsToShow: [EntryItem] = []
    @State private var text: String = ""
    @State private var buttonNmae: String = "pencil"
    @State private var placeHolder: String = "search entry"
    @State private var state: Bool = false
    @State private var openEntry: Bool = false
    @State private var entryView: diaryView?
    @State private var textFieldHelper: TextFieldHelper = TextFieldHelper()
    @State private var stopRecording: Bool = false
    
    @FocusState private var openKeboard: Bool
    
    @State private var currentView: entryView?
    
    var body: some View {
        VStack(alignment: .leading, content: {
            HStack {
                stateButton
                Spacer()
                SwiftSpeech.RecordButton()
                    .swiftSpeechRecordOnHold(locale: .current)
                    .onStartRecording(appendAction: { _ in
                        if !state {
                            textFieldHelper.original = text
                        }
                    })
                    .onRecognizeLatest(update: { transcribed in
                        let transcribed  =  {
                            guard let first = transcribed.first else {
                                return ""
                            }
                            
                            return transcribed.lowercased()
                                .replacingCharacters(in: ...transcribed.startIndex, with: "\(first)")
                        }()
                        
                        openKeboard = true
                        guard !stopRecording else {
                            stopRecording = false
                            return
                        }
                        if state {
                            currentView?.set(transcribed)
                        }
                        else {
                            let transcribed  = textFieldHelper.original.isEmpty ? transcribed : transcribed.lowercased()
                            text = textFieldHelper.original + transcribed
                            filter(value: text)
                        }
                    })
                    .onStopRecording(appendAction: { _ in
                        stopRecording = true
                        if state {
                            currentView?.setOrignal()
                            currentView?.isFirstResponder(true)
                        }
                        else {
                            textFieldHelper.original = text
                        }
                    })
                    .opacity(openEntry ? 0 : 1)
                    .animation(.easeIn, value: openEntry)
            }
            ThoughtsTextField
            animatbleView
        })
        .padding(.all, 20)
        .padding(.bottom, 20)
        .background(.white)
        .onTapGesture {
            openKeboard = false
            currentView?.isFirstResponder(false)
        }
        .onAppear(perform: {
            itemsToShow = items.filter { _ in return true }
            SwiftSpeech.requestSpeechRecognitionAuthorization()
        })
    }
    
    func filter(value: String) {
        itemsToShow = items.filter({ entry in
            return value.isEmpty || entry.text?.lowercased().contains(value.lowercased()) == true || "\(entry.time!)".contains(value.lowercased()) || entry.feel == value
        })
        
        itemsToShow.sort {
            $0.time! > $1.time!
        }
    }
    
    struct ScaleButtonStyle: ButtonStyle {
        func makeBody(configuration: Self.Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 1.1 : 1)
        }
    }
    
    @ViewBuilder
    var stateButton: some View {
        ZStack {
            Button(action: {
                withAnimation(.linear(duration: 0.4)) {
                    state.toggle()
                    openEntry = false
                }
                entryView = nil
                text = ""
                textFieldHelper.original = ""
                buttonNmae = state ? "magnifyingglass" : "pencil"
                placeHolder = state ? "write your thoughts!!" : "search entry"
                
            }, label: {
                Image(systemName: buttonNmae)
                    .scaledToFit()
                    .foregroundColor(.black)
                    .animation(.easeIn, value: state)
            })
            .frame(maxHeight: 76)
            .frame(minWidth: 76)
            .overlay(
                RoundedRectangle(cornerRadius: 38)
                    .stroke(.black, lineWidth: 0.5)
            )
        }
        .background(.white)
        .cornerRadius(38)
        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.2), radius: 5, x: 0, y: 3)
        .padding(.top, 20)
        .padding(.bottom, 20)
        .buttonStyle(ScaleButtonStyle())
    }
    
    @ViewBuilder
    var ThoughtsTextField: some View {
        let binding = Binding<String> {
            return text
        } set: { value in
            text = value
            filter(value: value)
        }
        
        TextField(
            "",
            text: binding,
            prompt: Text(placeHolder)
                .foregroundStyle(state ? .black.opacity(0.6) : .gray)
                .font(.system(size: 20))
        )
        .focused($openKeboard)
        .padding(12)
        .disabled(state)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(!state ? Color.gray : Color.clear, lineWidth: 0.5)
        )
        .foregroundStyle(.black)
        .multilineTextAlignment(state ? .center : .leading)
        .animation(.snappy, value: state)
        .underline(state ,color: .black.opacity(0.6))
        .onTapGesture {
            openKeboard = true
        }
    }
    
    @ViewBuilder
    var animatbleView: some View {
        @State var disabled: Bool = true
        @State var searchList = searchList(items: itemsToShow) {
            filter(value: text)
        } show: { entry in
            let items = items.filter { _ in return true }
            entryView = diaryView(items: items, selected: entry)
            
            withAnimation(.linear(duration: 0.4)) {
                openEntry = true
                state = true
            }
            
            buttonNmae = "magnifyingglass"
            placeHolder = "Diary"
        }
        
        if openEntry {
            if let entryView = entryView {
                entryView
                    .transition(.move(edge: .bottom))
            }
        }
        else if state {
            diaryView {
                withAnimation(.linear(duration: 0.4)) {
                    state = false
                }
            } currentBlock: { current in
                currentView = current
            }
            .transition(.move(edge: .bottom))
        }
        else {
            if items.isEmpty {
                Text("no entries")
                    .foregroundStyle(.black)
                    .font(.largeTitle)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
            }
            else if itemsToShow.isEmpty {
                Text("no results")
                    .foregroundStyle(.black)
                    .font(.largeTitle)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                    .onAppear(perform: {
                        filter(value: text)
                    })
            }
            else {
                searchList
                    .onAppear(perform: {
                        filter(value: text)
                    })
            }
        }
    }
}

struct diaryView: View {
    @State private var disabled: Bool
    
    @State private var currentView: entryView?
    
    @State private var isLoading: Bool = false
    
    private var setCurrentView: (entryView) -> () = { _ in }
    
    private var isNew: Bool
    
    private var current: Int
    
    private let entries: [Entry]
    
    private let showSave: Bool
    
    private var save: () -> ()
    
    init(items: [EntryItem], selected: EntryItem) {
        showSave = false
        isNew = false
        let selected = Entry(time: selected.time!, text: selected.text!, feel: selected.feel!)
        save = {}
        _disabled = State(initialValue: selected.text.isEmpty)
        
        entries = items.map { Entry(time: $0.time!, text: $0.text!, feel: $0.feel!) }
            .sorted(by: { entry1, entry2 in
                return entry1.time > entry2.time
            })
        
        current = entries.firstIndex(of: selected)!
    }
    
    init(dismiss: @escaping () -> (), currentBlock: @escaping (entryView) -> ()) {
        showSave = true
        isNew = true
        save = dismiss
        current = 0
        entries = [Entry(time: Date.now, text: "", feel: "")]
        setCurrentView = currentBlock
        _disabled = State(initialValue: true)
    }
    
    var body: some View {
        VStack {
            let ev = enrtriesView(current: current, entries: entries, track: { text in
                disabled = text.isEmpty
            }, setCurrentView: { current in
                currentView = current
                setCurrentView(current)
            }, isNew: isNew)
            
            ev
                .padding(.top, 10)
                .padding(.bottom, 20)
                .padding(.leading, 2)
                .padding(.trailing, isNew ? 20 : 42)
                .modifier(ActivityIndicatorModifier(isLoading: isLoading))
                .background {
                    if !isNew {
                        Image("back")
                            .resizable()
                    }
                }
            
            if showSave {
                Button(action: {
                    currentView?.isFirstResponder(false)
                    withAnimation {
                        isLoading = true
                    }
                    currentView?.save {
                        withAnimation {
                            isLoading = false
                        }
                        save()
                    }
                }, label: {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                })
                .frame(maxWidth: 400)
                .frame(maxHeight: 50)
                .background(.orange)
                .foregroundStyle(disabled ? .gray : .black)
                .disabled(disabled)
                .cornerRadius(15)
                .padding(.top, 10)
            }
        }
    }
}

struct searchList: View {
    var items: [EntryItem] = []
    var remove: () -> ()
    var show: (_ item: EntryItem) -> ()
    
    var body: some View {
        List {
            ForEach(items, id: \.self) { item in
                VStack(alignment: .leading, content: {
                    Text(item.time ?? Date.now, format: .dateTime.day().month().year().hour().minute().second())
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.gray)
                        .padding(.bottom, 8)
                    HStack {
                        Text(item.text ?? "no text")
                            .multilineTextAlignment(.leading)
                            .lineLimit(2, reservesSpace: false)
                            .foregroundStyle(.black)
                        Spacer()
                        VStack {
                            Text(item.feel ?? "no feel")
                            if (item.additional as? [String])?.isEmpty == false {
                                Spacer()
                                Button {
                                    
                                } label: {
                                    Text("additional")
                                }
                            }
                        }
                    }
                })
                .listRowBackground(Color.clear)
                .padding(.bottom, 4)
                .swipeActions {
                    Button(action: {
                        PersistenceController.shared.delete(item: item)
                        remove()
                    }, label: {
                        Text("delete")
                    })
                }
                .onTapGesture {
                    show(item)
                }
            }
        }
        .frame( maxWidth: .infinity)
        .edgesIgnoringSafeArea(.all)
        .listStyle(GroupedListStyle())
        .scrollIndicators(.hidden)
        .background(.clear)
        .scrollContentBackground(.hidden)
    }
}

struct enrtriesView: View {
    @State var current: Int = 0
    
    @State private var isFlippingForward = true
    
    @State var entries: [Entry] = []
    
    private let flipAmount = 360
    
    @State var track: (String) -> ()
    @State var setCurrentView: (entryView) -> ()
    
    let isNew: Bool
    
    func startTracking(block: @escaping (String) -> (), currentBlock: @escaping (entryView) -> ()) {
        track = block
        setCurrentView = currentBlock
    }
    
    var body: some View {
        if isNew {
            TabView(selection: $current) {
                ForEach(entries, id: \.self) { entry in
                    let ev = entryView(isNew: isNew, entry: entry, block: { text in
                        track(text)
                    })
                    
                    ev
                    .tag(entries.firstIndex(of: entry)!)
                    .onAppear {
                        setCurrentView(ev)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        else {
            VStack {
                GeometryReader { geometry in
                    ZStack {
                        ForEach(entries, id: \.self) { entry in
                            let ev = entryView(isNew: isNew, entry: entry, block: { text in
                                track(text)
                            })
                            
                            ev
                                .tag(entries.firstIndex(of: entry)!)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .rotation3DEffect(
                                    .degrees(Double(current == entries.firstIndex(of: entry) ? 0 : isFlippingForward ? -flipAmount : flipAmount)),
                                    axis: (x: 0, y: 1, z: 0),
                                    anchor: .leading,
                                    anchorZ: 0,
                                    perspective: 0.3
                                )
                                .opacity(current == entries.firstIndex(of: entry) ? 1 : 0)
                        }
                    }
                    .clipped()
                    .gesture(
                        DragGesture().onEnded { gesture in
                            let horizontalMove = gesture.translation.width
                            let verticalMove = gesture.translation.height
                            
                            if abs(horizontalMove) > abs(verticalMove) {
                                if horizontalMove < 0 && current < entries.count - 1 {
                                    isFlippingForward = true
                                    withAnimation(.linear(duration: 0.3)) {
                                        current += 1
                                    }
                                } else if horizontalMove > 0 && current > 0 {
                                    isFlippingForward = false
                                    withAnimation(.linear(duration: 0.3)) {
                                        current -= 1
                                    }
                                }
                            }
                        }
                    )
                }
                Text("Page \(current + 1) / \(entries.count)")
                    .foregroundStyle(.black)
                    .padding(.all, 10)
            }
        }
    }
}

struct entryView: View {
    @State private var textView: TextView
    @State private var feel: String
    
    let isNew: Bool
    let entry: Entry
    
    var startTracking: (String) -> () = { _ in }
    
    private let feelsDict: [String: String] = ["no-emotion": "😐",
                                               "joy": "😀",
                                               "sadness": "😞",
                                               "surprise": "😯",
                                               "anger": "😡",
                                               "disgust": "🤢",
                                               "fear": "😨"]
    
    private let feels: [String]
    
    init(isNew: Bool, entry: Entry, block: @escaping (String) -> ()) {
        self.isNew = isNew
        self.entry = entry
        _textView = State(initialValue: TextView(text: entry.text, feel: entry.feel))
        _feel = State(initialValue: entry.feel)
        
        feels = feelsDict.map { $0.value }
        
        startTracking = block
        textView
            .setUpdateUIView { text in
                block(text)
            }
    }
    
    func save(complete:@escaping () -> ()) {
        let text =  textView.text
        
        if textView.feel.isEmpty {
            Task {
                let result = await Service().analyze(string: text)
                
                switch result {
                case .success(let analyzed):
                    let predictions = (analyzed.first?.predictions ?? [])
                    var additional = predictions.map { feelsDict[$0.prediction] ?? "" }.filter { value in return !value.isEmpty }
                    guard !additional.isEmpty else { return }
                    let feel = additional.remove(at: 0)
                    PersistenceController.shared.save(text: text, feel: feel , date: entry.time, additional: additional)
                    complete()
                case .failure(let error):
                    complete()
                    print(error.localizedDescription)
                }
            }
        }
        else {
            complete()
            PersistenceController.shared.save(text: text, feel: textView.feel , date: entry.time)
        }
    }
    
    func set(_ transcribed: String?) {
        guard let transcribed else { return }
        let text = textView.original.isEmpty ? transcribed : transcribed.lowercased()
        textView.text = textView.original + text
        startTracking(textView.text)
    }
    
    func setOrignal() {
        textView.original = textView.text
    }
    
    func isFirstResponder(_ value: Bool) {
        textView.isFirstResponder(value)
    }
    
    var body: some View {
        ZStack {
            VStack {
                Text("Entry for \n\(entry.time, format: .dateTime.day().month().year().hour().minute().second())")
                    .foregroundStyle(.link)
                    .font(.system(size: 20))
                    .bold()
                    .multilineTextAlignment(.center)
                    .underline(true)
                    .bold()
                    .padding(.top, 5)
                
                HStack {
                    Text("How \(isNew ? "do" : "did") you feel?")
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .font(.system(size: 13.2))
                        .bold()
                    Menu {
                        ForEach(feels, id: \.self) { f in
                            Button(action: {
                                textView.feel = f
                                feel = f
                            }, label: {
                                Text(f)
                                    .multilineTextAlignment(.center)
                            })
                        }
                    } label: {
                        let feel = entry.feel.isEmpty ? feel :  entry.feel
                        Text(feel.isEmpty ? "if empty ai will fill for you" : feel)
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                            .font(.system(size: 13.2))
                            .foregroundStyle(.gray)
                            .opacity(feel.isEmpty ? 0.4 : 0.8)
                            .background(.clear)
                            .bold()
                    }
                    .disabled(!isNew)
                }
                .padding(.top, 5)
                .padding(.leading, 4)
                Text("Your Day")
                    .foregroundStyle(.black)
                    .font(.system(size: 10))
                    .padding(.top, 20)
                if isNew {
                    textView
                        .editable(isNew)
                }
                else {
                    ScrollView(.vertical) {
                        Text(entry.text)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .foregroundStyle(.black)
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .padding(.leading, 26)
            .padding(.trailing, 26)
        }
    }
}

struct ActivityIndicator: UIViewRepresentable {
    @Binding var isAnimating: Bool
    let style: UIActivityIndicatorView.Style

    func makeUIView(context: UIViewRepresentableContext<ActivityIndicator>) -> UIActivityIndicatorView {
        return UIActivityIndicatorView(style: style)
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context: UIViewRepresentableContext<ActivityIndicator>) {
        isAnimating ? uiView.startAnimating() : uiView.stopAnimating()
    }
}

struct ActivityIndicatorModifier: AnimatableModifier {
    var isLoading: Bool

    init(isLoading: Bool, color: Color = .primary, lineWidth: CGFloat = 3) {
        self.isLoading = isLoading
    }

    var animatableData: Bool {
        get { isLoading }
        set { isLoading = newValue }
    }

    func body(content: Content) -> some View {
        ZStack {
            if isLoading {
                GeometryReader { geometry in
                    ZStack(alignment: .center) {
                        content
                            .disabled(self.isLoading)
                            .blur(radius: self.isLoading ? 3 : 0)

                        VStack {
                            ActivityIndicator(isAnimating: .constant(true), style: .large)
                        }
                        .frame(width: geometry.size.width / 2,
                               height: geometry.size.height / 5)
                        .background(Color.secondary.colorInvert())
                        .foregroundColor(Color.primary)
                        .cornerRadius(20)
                        .opacity(self.isLoading ? 1 : 0)
                        .position(x: geometry.frame(in: .local).midX, y: geometry.frame(in: .local).midY)
                    }
                }
            } else {
                content
            }
        }
    }
}

struct TextView: UIViewRepresentable {
    private let textView = MyTextView(placeHolder: "Start here ....")
    
    var feel: String {
        set {
            textView.feel = newValue
        }
        get {
            return textView.feel
        }
    }
    
    var text: String {
        get {
            return textView.text
        }
        set {
            textView.set(string: newValue)
        }
    }
    
    var original: String {
        get {
            return textView.original
        }
        set {
            textView.original = newValue
        }
    }
    
    init(text: String, feel: String) {
        self.text = text
        self.feel = feel
    }
    
    func makeUIView(context: Context) -> UITextView {
        textView.textColor = .black
        return textView
    }
    
    mutating func setUpdateUIView(updateUIView: @escaping (String) -> ()) {
        textView
            .textViewDidChange { text in
                updateUIView(text)
            }
    }
    
    func editable(_ value: Bool) -> TextView {
        textView.isEditable = value
        return self
    }
    
    func isFirstResponder(_ value: Bool) {
        if value {
            textView.becomeFirstResponder()
        }
        else {
            textView.resignFirstResponder()
        }
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) { }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
