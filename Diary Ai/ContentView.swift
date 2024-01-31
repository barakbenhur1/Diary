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
    
    @State private var currentView: diaryView.entryView?
    
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
                            currentView?.isFirstResponder(true)
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
        .background(.teal.opacity(0.6))
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
        .multilineTextAlignment(state ? .center : .leading)
        .animation(.snappy, value: state)
        .underline(state ,color: .black.opacity(0.6))
        .onTapGesture {
            openKeboard = true
        }
    }
    
    @ViewBuilder
    var animatbleView: some View {
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
                entryView.transition(.move(edge: .bottom))
            }
        }
        else if state {
            diaryView { current in
                currentView = current
            } dismiss: {
                withAnimation(.linear(duration: 0.4)) {
                    state = false
                }
            }
            .transition(.move(edge: .bottom))
        }
        else {
            if items.isEmpty {
                Text("no entries")
                    .font(.largeTitle)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
            }
            else if itemsToShow.isEmpty {
                Text("no results")
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
    
    struct diaryView: View {
        @State private var disabled: Bool
        @State private var enrtriesPager: enrtriesView
        @State private var currentView: entryView?
        
        private var setCurrentView: (entryView) -> () = { _ in }

        private let showSave: Bool
        
        private var save: () -> ()
        
        init(items: [EntryItem], selected: EntryItem) {
            showSave = false
            let selected = Entry(time: selected.time!, text: selected.text!, feel: selected.feel!)
            save = {}
            _disabled = State(initialValue: selected.text.isEmpty)
            
            let entries = items.map { Entry(time: $0.time!, text: $0.text!, feel: $0.feel!) }
                .sorted(by: { entry1, entry2 in
                    return entry1.time > entry2.time
                })
            
            let current = entries.firstIndex(of: selected) ?? 0
            
            _enrtriesPager = State(wrappedValue: enrtriesView(current: current, entries: entries, isNew: false))
        }
        
        init(currentBlock: @escaping (entryView) -> (), dismiss: @escaping () -> ()) {
            showSave = true
            let selected = Entry(time:  Date.now, text: "", feel: "")
            save = dismiss
            setCurrentView = currentBlock
            _disabled = State(initialValue: true)
            
            _enrtriesPager = State(wrappedValue: enrtriesView(current: 0, entries: [selected], isNew: true))
        }
        
        var body: some View {
            VStack {
                enrtriesPager
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                    .padding(.leading, 2)
                    .padding(.trailing, 20)
                    .onAppear(
                        perform: {
                            enrtriesPager
                                .startTracking { text in
                                    disabled = text.isEmpty
                                } currentBlock: { current in
                                    currentView = current
                                    setCurrentView(current)
                                }
                            
                        })
                    .background {
                        Image("back")
                            .resizable()
                    }
                if showSave {
                    Button(action: {
                        currentView?.save()
                        save()
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
        
        struct enrtriesView: View {
            @State var current: Int
           
            @State var entries: [Entry] = []
            let isNew: Bool
            
            var track: (String) -> () = { _ in }
            var setCurrentView: (entryView) -> () = { _ in }
            
            mutating func startTracking(block: @escaping (String) -> (), currentBlock: @escaping (entryView) -> ()) {
                track = block
                setCurrentView = currentBlock
            }
            
            var body: some View {
                GeometryReader {
                    let rect = $0.frame(in: .global)
                    let minX = (rect.minX - 50) < 0 ? (rect.minX - 50) : -(rect.minX - 50)
                    let progress = (minX) / rect.width
                    
                    TabView(selection: $current) {
                        ForEach(entries, id: \.self) { entry in
                            var ev = entryView(isNew: isNew, entry: entry)
                            
                            ev.startTracking { text in
                                track(text)
                            }
                            .tag(entries.firstIndex(of: entry)!)
                            .onAppear(
                                perform: {
                                    setCurrentView(ev)
                                }
                            )
                            .rotation3DEffect(
                                .init(degrees: -2), axis: (x:0, y: 1, z: 0), anchor: .leading, perspective: 1)
                            .modifier(CustomProjection(value: 1+(-progress < 1 ? progress : -1.0)))
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: isNew ? .never : .always))
                }
            }
        }
        
        struct CustomProjection: GeometryEffect{
            var value: CGFloat
            
            var animatableData: CGFloat{
                get{
                    return value
                }
                set{
                    value = newValue
                }
            }
            func effectValue(size: CGSize) -> ProjectionTransform {
                var transform = CATransform3DIdentity
                transform.m11 = (value == 0 ? 0.0001 : value)
                return .init(transform)
            }
        }
        
        struct entryView: View {
            @State private var textView: TextView = TextView()
            @State private var feel: String = ""
            
            let isNew: Bool
            let entry: Entry
            
            var startTracking: (String) -> () = { _ in }
            
            let feels: [String] = ["😀", "😞", "😭", "😡", "😨"]
            
            mutating func startTracking(block: @escaping (String) -> ()) -> entryView  {
                textView.text = entry.text
                startTracking = block
                textView
                    .setUpdateUIView { text in
                        block(text)
                    }
                
                return self
            }
            
            func save() {
                PersistenceController.shared.save(text: textView.text, feel: textView.feel, date: entry.time)
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
                VStack {
                    Text("Entry for \n\(entry.time, format: .dateTime.day().month().year().hour().minute().second())")
                        .foregroundStyle(.orange)
                        .font(.system(size: 20))
                        .bold()
                        .multilineTextAlignment(.center)
                        .underline(true)
                        .bold()
                    
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
                                .bold()
                        }
                        .disabled(!isNew)
                        Spacer()
                    }
                    .padding(.top, 5)
                    .padding(.leading, 4)
                    textView
                        .editable(isNew)
                }
                .padding(.leading, 26)
                .padding(.trailing, 26)
                .background {
                    Image("page")
                        .resizable()
                        .scaledToFill()
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
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 8)
                        HStack {
                            Text(item.text ?? "no text")
                                .multilineTextAlignment(.leading)
                                .lineLimit(2, reservesSpace: false)
                            Spacer()
                            Text(item.feel ?? "no feel")
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
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
