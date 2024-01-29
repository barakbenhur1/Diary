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
    
    var body: some View {
        VStack(alignment: .leading, content: {
            stateButton
            ThoughtsTextField
            animatbleView
        })
        .padding(.all, 20)
        .background(.teal.opacity(0.2))
        .onAppear(perform: {
            itemsToShow = items.filter { _ in return true }
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
    
    @ViewBuilder
    var stateButton: some View {
        Button(action: {
            withAnimation(.linear(duration: 0.4)) {
                state.toggle()
            }
            openEntry = false
            entryView = nil
            text = ""
            buttonNmae = state ? "magnifyingglass" : "pencil"
            placeHolder = state ? "write your thoughts!!" : "search entry"
            
        }, label: {
            Image(systemName: buttonNmae)
                .scaledToFit()
                .foregroundColor(.black)
                .animation(.easeIn, value: state)
        })
        .frame(maxHeight: 50)
        .frame(minWidth: 50)
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(.black, lineWidth: 0.5)
        )
        .padding(.bottom, 20)
    }
    
    @ViewBuilder
    var ThoughtsTextField: some View {
        let binding = Binding<String> {
            return text
        } set: { value in
            text = value
            filter(value: value)
        }
        
        TextField(placeHolder, text: binding)
            .padding(12)
            .disabled(state)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(!state ? Color.gray : Color.clear, lineWidth: 0.5)
            )
            .multilineTextAlignment(state ? .center : .leading)
            .animation(.easeIn, value: state)
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
            diaryView {
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
        
        init(dismiss: @escaping () -> ()) {
            showSave = true
            let selected = Entry(time:  Date.now, text: "", feel: "")
            save = dismiss
            _disabled = State(initialValue: true)
            
            _enrtriesPager = State(wrappedValue: enrtriesView(current: 0, entries: [selected], isNew: true))
        }
        
        var body: some View {
            VStack {
                enrtriesPager
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                    .padding(.leading, 2)
                    .padding(.trailing, 15)
                    .onAppear(
                        perform: {
                            enrtriesPager
                                .startTracking { text in
                                    disabled = text.isEmpty
                                } currentBlock: { current in
                                    currentView = current
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
            let entries: [Entry]
            let isNew: Bool
            
            var track: (String) -> () = { _ in }
            var setCurrentView: (entryView) -> () = { _ in }
            
            mutating func startTracking(block: @escaping (String) -> (), currentBlock: @escaping (entryView) -> ()) {
                track = block
                setCurrentView = currentBlock
            }
            
            var body: some View {
                TabView(selection: $current) {
                    ForEach(entries, id: \.self) { entry in
                        let ev = entryView(isNew: isNew, entry: entry)
                        
                        ev.startTracking { text in
                            track(text)
                        }
                        .tag(entries.firstIndex(of: entry)!)
                        .onAppear(
                            perform: {
                                setCurrentView(ev)
                            }
                        )
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: isNew ? .never : .always))
            }
        }
        
        struct entryView: View {
            @State var textView: TextView = TextView()
            @State var feel: String = ""
            
            let isNew: Bool
            let entry: Entry
            
            let feels: [String] = ["😀", "😞", "😭", "😡", "😨"]
            
            func startTracking(block: @escaping (String) -> ()) -> entryView  {
                textView.set(text: entry.text)
                textView
                    .setUpdateUIView { text in
                        block(text)
                    }
                
                return self
            }
            
            func save() {
                PersistenceController.shared.save(text: textView.text, feel: textView.feel, date: entry.time)
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
            return textView.text
        }
        
        func makeUIView(context: Context) -> UITextView {
            return textView
        }
        
        mutating func setUpdateUIView(updateUIView: @escaping (String) -> ()) {
            textView
                .textViewDidChange { text in
                    updateUIView(text)
                }
        }
        
        func set(text: String) {
            textView.set(string: text)
        }
        
        func editable(_ value: Bool) -> TextView {
            textView.isEditable = value
            return self
        }
        
        func updateUIView(_ uiView: UITextView, context: Context) { }
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
