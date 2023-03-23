import ComposableArchitecture
import ComposablePresentation
import SwiftUI

struct ColorNavigationStackExample: ReducerProtocol {
  struct State {
    var stack: IdentifiedArrayOf<Destination.State> = []
  }
  
  enum Action {
    case updatePath([Destination.State.ID])
    case start
    case popToRoot
    case popTo(Destination.State.ID)
    case destination(_ id: Destination.State.ID, _ action: Destination.Action)
  }
  
  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
        case .updatePath(let path):
          state.stack = state.stack.filter { destination in
            path.contains(destination.id)
          }
          return .none
          
        case .start:
          state.stack = [.init(id: "1")]
          return .none
          
        case .popTo(let id):
          if let index = state.stack.index(id: id) {
            state.stack = .init(uniqueElements: state.stack[state.stack.startIndex...index])
          }
          return .none
          
        case .destination(let id, .push(let path)):
          state.stack.append(contentsOf: path.map { .init(id: "\(id).\($0)") })
          return .none
          
        case .destination(_, .set(let path)):
          state.stack = .init(uniqueElements: path.map { id in
            state.stack[id: id] ?? .init(id: id)
          })
          return .none
          
        case .destination(_, .pop):
          _ = state.stack.popLast()
          return .none
          
        case .popToRoot, .destination(_, .popToRoot):
          state.stack.removeAll()
          return .none
          
        case .destination(_, .shuffle):
          state.stack.shuffle()
          return .none
          
        case .destination(_, _):
          return .none
      }
    }
    .presentingForEach(
      state: \.stack,
      action: /Action.destination,
      onPresent: .init { id, state in
        // Start timer when destination is added to the stack. When multiple destinations are pushed onto the stack, only the view of the last one will receive `.onAppear` event (that starts the timer too).
          .task { .destination(id, .timer(.start)) }
      },
      element: Destination.init
    )
  }
  
  // MARK: - Child Reducers
  
  struct Destination: ReducerProtocol {
    struct State: Identifiable {
      var id: String
      var timer = ColorReducer.State()
    }
    
    enum Action {
      case push([Destination.State.ID])
      case set([Destination.State.ID])
      case pop
      case popToRoot
      case shuffle
      case timer(ColorReducer.Action)
    }
    
    var body: some ReducerProtocol<State, Action> {
      Scope(state: \.timer, action: /Action.timer) {
        ColorReducer()
      }
    }
  }
}

struct ColorNavigationStackExampleView: View {
  let store: StoreOf<ColorNavigationStackExample>
  
  var body: some View {
    VStack(spacing: 0) {
      NavigationStackWithStore(store.scope(
        state: { Array($0.stack.ids) },
        action: ColorNavigationStackExample.Action.updatePath
      )) {
        Button {
          ViewStore(store.stateless).send(.start)
        } label: {
          Text("Start")
        }
        .navigationDestination(
          forEach: store.scope(state: \.stack),
          action: ColorNavigationStackExample.Action.destination,
          destination: DestinationView.init(store:)
        )
      }
      
      Divider()
      
      WithViewStore(store, observe: \.stack.ids) { viewStore in
        ScrollView(.horizontal, showsIndicators: false) {
          HStack {
            Button {
              viewStore.send(.popToRoot)
            } label: {
              Text("Root")
            }
            
            ForEach(viewStore.state, id: \.self) { id in
              Text("→")
              Button {
                viewStore.send(.popTo(id))
              } label: {
                Text(id)
              }
            }
          }
        }
        .padding()
      }
    }
  }
  
  // MARK: - Child Views
  
  struct DestinationView: View {
    let store: StoreOf<ColorNavigationStackExample.Destination>
    
    struct ViewState: Equatable {
      init(state: ColorNavigationStackExample.Destination.State) {
        title = state.id
      }
      
      var title: String
    }
    
    var body: some View {
      WithViewStore(store, observe: ViewState.init) { viewStore in
        ScrollView {
          Section {
            ColorView(store: store.scope(
              state: \.timer,
              action: ColorNavigationStackExample.Destination.Action.timer
            ))
          } header: {
            Text("Timer")
          }
          .padding()
          
          Section {
            Button(action: { viewStore.send(.push(["1"])) }) {
              Text("Push 1")
            }
            
            Button(action: { viewStore.send(.push(["2"])) }) {
              Text("Push 2")
            }
            
            Button(action: { viewStore.send(.push(["3"])) }) {
              Text("Push 3")
            }
            
            Button(action: { viewStore.send(.push(["1", "2", "3"])) }) {
              Text("Push 1→2→3")
            }
            
            Button(action: { viewStore.send(.push(["3", "2", "1"])) }) {
              Text("Push 3→2→1")
            }
            
            Button(action: { viewStore.send(.set(["1", "2", "3"])) }) {
              Text("Set 1→2→3")
            }
            
            Button(action: { viewStore.send(.set(["3", "2", "1"])) }) {
              Text("Set 3→2→1")
            }
            
            Button(action: { viewStore.send(.pop) }) {
              Text("Pop")
            }
            
            Button(action: { viewStore.send(.popToRoot) }) {
              Text("Pop to root")
            }
            
            Button(action: { viewStore.send(.shuffle) }) {
              Text("Shuffle")
            }
          } header: {
            Text("Stack navigation")
          }
//          .padding()
        }
        .navigationTitle(viewStore.title)
      }
    }
  }
}

struct ColorNavigationStackExample_Previews: PreviewProvider {
  static var previews: some View {
    ColorNavigationStackExampleView(store: Store(
      initialState: ColorNavigationStackExample.State(),
      reducer: ColorNavigationStackExample()
    ))
  }
}


struct ColorReducer: ReducerProtocol {
  
  // MARK: State
  struct State: Equatable, Identifiable {
    
    enum Destination: Equatable {
      case redState(RedColorReducer.State)
      case greenState(GreenColorReducer.State)
      case blueState(BlueColorReducer.State)
    }
    
    var count: Int = 0
    let id = UUID()
    var destination: ColorReducer.State.Destination?
    
  }
  
  // MARK: Action
  enum Action: Equatable {
    enum Destination: Equatable {
      case redAction(RedColorReducer.Action)
      case greenAction(GreenColorReducer.Action)
      case blueAction(BlueColorReducer.Action)
    }
    case viewOnAppear
    case viewOnDisappear
    case none
    case increment
    case decrement
    case start
    case tick
    case present(ColorReducer.State.Destination?)
    case destination(ColorReducer.Action.Destination)
  }
  
  @Dependency(\.uuid) var uuid
  
  // MARK: Reducer
  var body: some ReducerProtocolOf<Self> {
    Reduce { state, action in
      switch action {
        case .viewOnAppear:
          let destination = [
            ColorReducer.State.Destination.redState(.init()),
            ColorReducer.State.Destination.greenState(.init()),
            ColorReducer.State.Destination.blueState(.init()),
          ].shuffled()
            .first
          state.destination = destination
          return EffectTask(value: .start)
        case .viewOnDisappear:
//          state.count = 0
          break
        case .increment:
          state.count += 1
          return .none
        case .decrement:
          state.count -= 1
          return .none
        case .start:
          // NB: Clocks are available on iOS ≥ 16
          return EffectTask.timer(id: state.id, every: .seconds(1), on: DispatchQueue.main)
            .map { _ in .tick }
          
        case .tick:
          state.count += 1
          return .none
        case .present(let destination):
          state.destination = destination
          return .none
          
        case .destination(_):
          return .none
        default:
          return .none
      }
      return .none
    }
    .presentingDestinations()
    ._printChanges()
  }
}

extension ReducerProtocolOf<ColorReducer> {
  func presentingDestinations() -> some ReducerProtocol<State, Action> {
    self
//      .presentingRedColorReduer()
//      .presentingGreenColorReducer()
//      .presentingBlueColorReducer()
  }
  func presentingRedColorReduer() -> some ReducerProtocol<State, Action> {
    presenting(
      unwrapping: \.destination,
      case: /State.Destination.redState,
      id: .notNil(),
      action: (/Action.destination).appending(path: /Action.Destination.redAction),
      presented: RedColorReducer.init
    )
  }
  func presentingGreenColorReducer() -> some ReducerProtocol<State, Action> {
    presenting(
      unwrapping: \.destination,
      case: /State.Destination.greenState,
      id: .notNil(),
      action: (/Action.destination).appending(path: /Action.Destination.greenAction),
      presented: GreenColorReducer.init
    )
  }
  func presentingBlueColorReducer() -> some ReducerProtocol<State, Action> {
    presenting(
      unwrapping: \.destination,
      case: /State.Destination.blueState,
      id: .notNil(),
      action: (/Action.destination).appending(path: /Action.Destination.blueAction),
      presented: BlueColorReducer.init
    )
  }
}

struct ColorView: View {
  
  private let store: StoreOf<ColorReducer>
  
  @ObservedObject
  private var viewStore: ViewStoreOf<ColorReducer>
  
  init(store: StoreOf<ColorReducer>? = nil) {
    let unwrapStore = store ?? Store(
      initialState: ColorReducer.State(),
      reducer: ColorReducer()
    )
    self.store = unwrapStore
    self.viewStore = ViewStore(unwrapStore)
  }
  
  var body: some View {
      ZStack {
        IfLetStore(store.scope(state: \.destination)) { store in
          SwitchStore(store) {
            CaseLet(
              state: (/ColorReducer.State.Destination.redState).extract(from:),
              action: { ColorReducer.Action.destination(.redAction($0)) },
              then: RedColorView.init(store:)
            )
            CaseLet(
              state: (/ColorReducer.State.Destination.greenState).extract(from:),
              action: { ColorReducer.Action.destination(.greenAction($0)) },
              then: GreenColorView.init(store:)
            )
            CaseLet(
              state: (/ColorReducer.State.Destination.blueState).extract(from:),
              action: { ColorReducer.Action.destination(.blueAction($0)) },
              then: BlueColorView.init(store:)
            )
          }
        } else: {
          Color.black
        }
        VStack {
          HStack {
            Button {
              viewStore.send(.increment)
            } label: {
              Text("+")
                .foregroundColor(.white)
            }
            Text("\(viewStore.count)")
              .foregroundColor(.white)
            Button {
              viewStore.send(.decrement)
            } label: {
              Text("-")
                .foregroundColor(.white)
            }
          }
          
          HStack {
            Button {
              ViewStore(store.stateless).send(.present(.redState(.init())))
            } label: {
              Text("Red")
                .foregroundColor(.white)
            }
            Button {
              ViewStore(store.stateless).send(.present(.greenState(.init())))
            } label: {
              Text("Green")
                .foregroundColor(.white)
            }
            Button {
              ViewStore(store.stateless).send(.present(.blueState(.init())))
            } label: {
              Text("Blue")
                .foregroundColor(.white)
            }
          }
        }
      }
    .onAppear {
      viewStore.send(.viewOnAppear)
    }
    .onDisappear {
//      viewStore.send(.viewOnDisappear)
    }
  }
}

struct RedColorReducer: ReducerProtocol {
  
  // MARK: State
  struct State: Equatable {

  }
  
  // MARK: Action
  enum Action: Equatable {
    case none
  }
  
  @Dependency(\.uuid) var uuid
  
  var body: some ReducerProtocolOf<Self> {
    Reduce { state, action in
      switch action {
        case .none:
          return .none
      }
    }
  }
}

struct RedColorView: View {
  
  private let store: StoreOf<RedColorReducer>
  
  @ObservedObject
  private var viewStore: ViewStoreOf<RedColorReducer>
  
  init(store: StoreOf<RedColorReducer>? = nil) {
    let unwrapStore = store ?? Store(
      initialState: RedColorReducer.State(),
      reducer: RedColorReducer()
    )
    self.store = unwrapStore
    self.viewStore = ViewStore(unwrapStore)
  }
  
  var body: some View {
    Color.red
  }
}

struct GreenColorReducer: ReducerProtocol {
  
  // MARK: State
  struct State: Equatable {
    
  }
  
  // MARK: Action
  enum Action: Equatable {
    case none
  }
  
  @Dependency(\.uuid) var uuid
  
  var body: some ReducerProtocolOf<Self> {
    Reduce { state, action in
      switch action {
        case .none:
          return .none
      }
    }
  }
}

struct GreenColorView: View {
  
  private let store: StoreOf<GreenColorReducer>
  
  @ObservedObject
  private var viewStore: ViewStoreOf<GreenColorReducer>
  
  init(store: StoreOf<GreenColorReducer>? = nil) {
    let unwrapStore = store ?? Store(
      initialState: GreenColorReducer.State(),
      reducer: GreenColorReducer()
    )
    self.store = unwrapStore
    self.viewStore = ViewStore(unwrapStore)
  }
  
  var body: some View {
    Color.green
  }
}

struct BlueColorReducer: ReducerProtocol {
  
  // MARK: State
  struct State: Equatable {
    
  }
  
  // MARK: Action
  enum Action: Equatable {
    case none
  }
  
  @Dependency(\.uuid) var uuid
  
  var body: some ReducerProtocolOf<Self> {
    Reduce { state, action in
      switch action {
        case .none:
          return .none
      }
    }
  }
}

struct BlueColorView: View {
  
  private let store: StoreOf<BlueColorReducer>
  
  @ObservedObject
  private var viewStore: ViewStoreOf<BlueColorReducer>
  
  init(store: StoreOf<BlueColorReducer>? = nil) {
    let unwrapStore = store ?? Store(
      initialState: BlueColorReducer.State(),
      reducer: BlueColorReducer()
    )
    self.store = unwrapStore
    self.viewStore = ViewStore(unwrapStore)
  }
  
  var body: some View {
    Color.blue
  }
}
