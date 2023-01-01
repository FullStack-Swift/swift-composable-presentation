import Combine
import ComposableArchitecture
import XCTest
@testable import ComposablePresentation

final class PresentingForEachReducerTests: XCTestCase {
  func testPresentingWithIdentifiedArray() {
    var didPresent = [Element.State.ID]()
    var didRun = [Element.State.ID]()
    var didFireEffect = [Element.State.ID]()
    var didDismiss = [Element.State.ID]()
    var didCancelEffect = [Element.State.ID]()

    struct Parent: ReducerProtocol {
      struct State: Equatable {
        var elements: IdentifiedArrayOf<Element.State>
      }

      enum Action: Equatable {
        case addElement(id: Int)
        case removeElement(id: Int)
        case element(id: Int, action: Element.Action)
      }

      func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
        switch action {
        case .addElement(let id):
          state.elements.append(Element.State(id: id))
          return .none

        case .removeElement(let id):
          _ = state.elements.remove(id: id)
          return .none

        case .element(_, _):
          return .none
        }
      }
    }

    struct Element: ReducerProtocol {
      struct State: Equatable, Identifiable {
        var id: Int
      }

      enum Action: Equatable {
        case performEffect
        case didPerformEffect
      }

      var effect: (State.ID) -> Effect<Void, Never>
      var onReduce: (State.ID) -> Void

      func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
        onReduce(state.id)
        switch action {
        case .performEffect:
          return effect(state.id)
            .map { _ in .didPerformEffect }
            .eraseToEffect()

        case .didPerformEffect:
          return .none
        }
      }
    }

    let store = TestStore(
      initialState: Parent.State(elements: []),
      reducer: Parent()
        .presentingForEach(
          state: \.elements,
          action: /Parent.Action.element(id:action:),
          onPresent: .init { id, _ in
            didPresent.append(id)
            return .none
          },
          onDismiss: .init { id, _ in
            didDismiss.append(id)
            return .none
          },
          element: {
            Element(
              effect: { id in
                Empty(completeImmediately: false)
                  .handleEvents(
                    receiveSubscription: { _ in didFireEffect.append(id) },
                    receiveCancel: { didCancelEffect.append(id) }
                  )
                  .eraseToEffect()
              },
              onReduce: { id in
                didRun.append(id)
              }
            )
          }
        )
    )

    store.send(.addElement(id: 1)) {
      $0.elements.append(Element.State(id: 1))
    }

    XCTAssertEqual(didPresent, [1])
    XCTAssertEqual(didRun, [])
    XCTAssertEqual(didFireEffect, [])
    XCTAssertEqual(didDismiss, [])
    XCTAssertEqual(didCancelEffect, [])

    store.send(.element(id: 1, action: .performEffect))

    XCTAssertEqual(didPresent, [1])
    XCTAssertEqual(didRun, [1])
    XCTAssertEqual(didFireEffect, [1])
    XCTAssertEqual(didDismiss, [])
    XCTAssertEqual(didCancelEffect, [])

    store.send(.addElement(id: 2)) {
      $0.elements.append(Element.State(id: 2))
    }

    XCTAssertEqual(didPresent, [1, 2])
    XCTAssertEqual(didRun, [1])
    XCTAssertEqual(didFireEffect, [1])
    XCTAssertEqual(didDismiss, [])
    XCTAssertEqual(didCancelEffect, [])

    store.send(.element(id: 2, action: .performEffect))

    XCTAssertEqual(didPresent, [1, 2])
    XCTAssertEqual(didRun, [1, 2])
    XCTAssertEqual(didFireEffect, [1, 2])
    XCTAssertEqual(didDismiss, [])
    XCTAssertEqual(didCancelEffect, [])

    store.send(.removeElement(id: 1)) {
      $0.elements.remove(id: 1)
    }

    XCTAssertEqual(didPresent, [1, 2])
    XCTAssertEqual(didRun, [1, 2])
    XCTAssertEqual(didFireEffect, [1, 2])
    XCTAssertEqual(didDismiss, [1])
    XCTAssertEqual(didCancelEffect, [1])

    store.send(.removeElement(id: 2)) {
      $0.elements.remove(id: 2)
    }

    XCTAssertEqual(didPresent, [1, 2])
    XCTAssertEqual(didRun, [1, 2])
    XCTAssertEqual(didFireEffect, [1, 2])
    XCTAssertEqual(didDismiss, [1, 2])
    XCTAssertEqual(didCancelEffect, [1, 2])
  }
}