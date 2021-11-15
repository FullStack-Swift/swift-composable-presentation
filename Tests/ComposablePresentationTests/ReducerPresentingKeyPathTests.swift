import Combine
import ComposableArchitecture
import XCTest
@testable import ComposablePresentation

final class ReducerPresentingKeyPathTests: XCTestCase {
  func testCancelEffectsOnDismiss() {
    var didRunPresentedReducer = 0
    var didCancelPresentedEffects = 0
    var didSubscribeToEffect = 0
    var didCancelEffect = 0

    let store = TestStore(
      initialState: MasterState(),
      reducer: masterReducer
        .presenting(
          detailReducer,
          state: \.detail,
          action: /MasterAction.detail,
          environment: \.detail,
          onRun: { didRunPresentedReducer += 1 },
          onCancel: { didCancelPresentedEffects += 1 }
        ),
      environment: MasterEnvironment(
        detail: DetailEnvironment(effect: {
          Empty(completeImmediately: false)
            .handleEvents(
              receiveSubscription: { _ in didSubscribeToEffect += 1 },
              receiveCancel: { didCancelEffect += 1 }
            )
            .eraseToEffect()
        })
      )
    )

    store.send(.presentDetail) {
      $0.detail = DetailState()
    }

    XCTAssertEqual(didRunPresentedReducer, 0)
    XCTAssertEqual(didCancelPresentedEffects, 0)
    XCTAssertEqual(didSubscribeToEffect, 0)
    XCTAssertEqual(didCancelEffect, 0)

    store.send(.detail(.performEffect))

    XCTAssertEqual(didRunPresentedReducer, 1)
    XCTAssertEqual(didCancelPresentedEffects, 0)
    XCTAssertEqual(didSubscribeToEffect, 1)
    XCTAssertEqual(didCancelEffect, 0)

    store.send(.dismissDetail) {
      $0.detail = nil
    }

    XCTAssertEqual(didRunPresentedReducer, 1)
    XCTAssertEqual(didCancelPresentedEffects, 1)
    XCTAssertEqual(didSubscribeToEffect, 1)
    XCTAssertEqual(didCancelEffect, 1)

    store.send(.dismissDetail)

    XCTAssertEqual(didRunPresentedReducer, 1)
    XCTAssertEqual(didCancelPresentedEffects, 1)
    XCTAssertEqual(didSubscribeToEffect, 1)
    XCTAssertEqual(didCancelEffect, 1)
  }
}

// MARK: - Master component

private struct MasterState: Equatable {
  var detail: DetailState?
}

private enum MasterAction: Equatable {
  case presentDetail
  case dismissDetail
  case detail(DetailAction)
}

private struct MasterEnvironment {
  var detail: DetailEnvironment
}

private typealias MasterReducer = Reducer<MasterState, MasterAction, MasterEnvironment>

private let masterReducer = MasterReducer { state, action, env in
  switch action {
  case .presentDetail:
    state.detail = DetailState()
    return .none

  case .dismissDetail:
    state.detail = nil
    return .none

  case .detail:
    return .none
  }
}

// MARK: - Detail component

private struct DetailState: Equatable {}

private enum DetailAction: Equatable {
  case performEffect
  case didPerformEffect
}

private struct DetailEnvironment {
  var effect: () -> Effect<Void, Never>
}

private typealias DetailReducer = Reducer<DetailState, DetailAction, DetailEnvironment>

private let detailReducer = DetailReducer { state, action, env in
  switch action {
  case .performEffect:
    return env.effect()
      .map { _ in DetailAction.didPerformEffect }
      .eraseToEffect()

  case .didPerformEffect:
    return .none
  }
}