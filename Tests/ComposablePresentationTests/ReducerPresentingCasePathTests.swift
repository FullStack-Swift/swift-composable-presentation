import CasePaths
import Combine
import ComposableArchitecture
import XCTest
@testable import ComposablePresentation

final class ReducerPresentingCasePathTests: XCTestCase {
  func testCancelEffectsOnDismiss() {
    var didRunFirstPresentedReducer = 0
    var didRunSecondPresentedReducer = 0
    var didCancelFirstPresentedEffects = 0
    var didCancelSecondPresentedEffects = 0
    var didSubscribeToFirstEffect = 0
    var didCancelFirstEffect = 0
    var didSubscribeToSecondEffect = 0
    var didCancelSecondEffect = 0

    let store = TestStore(
      initialState: MasterState.first(FirstDetailState()),
      reducer: masterReducer
        .presenting(
          firstDetailReducer,
          state: /MasterState.first,
          action: /MasterAction.first,
          environment: \.firstDetail,
          onRun: { didRunFirstPresentedReducer += 1 },
          onCancel: { didCancelFirstPresentedEffects += 1 }
        )
        .presenting(
          secondDetailReducer,
          state: /MasterState.second,
          action: /MasterAction.second,
          environment: \.secondDetail,
          onRun: { didRunSecondPresentedReducer += 1 },
          onCancel: { didCancelSecondPresentedEffects += 1 }
        ),
      environment: MasterEnvironment(
        firstDetail: FirstDetailEnvironment(effect: {
          Empty(completeImmediately: false)
            .handleEvents(
              receiveSubscription: { _ in didSubscribeToFirstEffect += 1 },
              receiveCancel: { didCancelFirstEffect += 1 }
            )
            .eraseToEffect()
        }),
        secondDetail: SecondDetailEnvironment(effect: {
          Empty(completeImmediately: false)
            .handleEvents(
              receiveSubscription: { _ in didSubscribeToSecondEffect += 1 },
              receiveCancel: { didCancelSecondEffect += 1 }
            )
            .eraseToEffect()
        })
      )
    )

    store.send(.first(.performEffect))

    XCTAssertEqual(didRunFirstPresentedReducer, 1)
    XCTAssertEqual(didRunSecondPresentedReducer, 0)
    XCTAssertEqual(didCancelFirstPresentedEffects, 0)
    XCTAssertEqual(didCancelSecondPresentedEffects, 0)
    XCTAssertEqual(didSubscribeToFirstEffect, 1)
    XCTAssertEqual(didCancelFirstEffect, 0)
    XCTAssertEqual(didSubscribeToSecondEffect, 0)
    XCTAssertEqual(didCancelSecondEffect, 0)

    store.send(.presentSecondDetail) {
      $0 = .second(SecondDetailState())
    }

    XCTAssertEqual(didRunFirstPresentedReducer, 1)
    XCTAssertEqual(didRunSecondPresentedReducer, 0)
    XCTAssertEqual(didCancelFirstPresentedEffects, 1)
    XCTAssertEqual(didCancelSecondPresentedEffects, 0)
    XCTAssertEqual(didSubscribeToFirstEffect, 1)
    XCTAssertEqual(didCancelFirstEffect, 1)
    XCTAssertEqual(didSubscribeToSecondEffect, 0)
    XCTAssertEqual(didCancelSecondEffect, 0)

    store.send(.second(.performEffect))

    XCTAssertEqual(didRunFirstPresentedReducer, 1)
    XCTAssertEqual(didRunSecondPresentedReducer, 1)
    XCTAssertEqual(didCancelFirstPresentedEffects, 1)
    XCTAssertEqual(didCancelSecondPresentedEffects, 0)
    XCTAssertEqual(didSubscribeToFirstEffect, 1)
    XCTAssertEqual(didCancelFirstEffect, 1)
    XCTAssertEqual(didSubscribeToSecondEffect, 1)
    XCTAssertEqual(didCancelSecondEffect, 0)

    store.send(.presentFirstDetail) {
      $0 = .first(FirstDetailState())
    }

    XCTAssertEqual(didRunFirstPresentedReducer, 1)
    XCTAssertEqual(didRunSecondPresentedReducer, 1)
    XCTAssertEqual(didCancelFirstPresentedEffects, 1)
    XCTAssertEqual(didCancelSecondPresentedEffects, 1)
    XCTAssertEqual(didSubscribeToFirstEffect, 1)
    XCTAssertEqual(didCancelFirstEffect, 1)
    XCTAssertEqual(didSubscribeToSecondEffect, 1)
    XCTAssertEqual(didCancelSecondEffect, 1)
  }
}

// MARK: - Master component

private enum MasterState: Equatable {
  case first(FirstDetailState)
  case second(SecondDetailState)
}

private enum MasterAction: Equatable {
  case presentFirstDetail
  case presentSecondDetail
  case first(FirstDetailAction)
  case second(SecondDetailAction)
}

private struct MasterEnvironment {
  var firstDetail: FirstDetailEnvironment
  var secondDetail: SecondDetailEnvironment
}

private let masterReducer = Reducer<MasterState, MasterAction, MasterEnvironment>
{ state, action, env in
  switch action {
  case .presentFirstDetail:
    state = .first(FirstDetailState())
    return .none

  case .presentSecondDetail:
    state = .second(SecondDetailState())
    return .none

  case .first(_), .second(_):
    return .none
  }
}

// MARK: - FirstDetail component

private struct FirstDetailState: Equatable {}

private enum FirstDetailAction: Equatable {
  case performEffect
  case didPerformEffect
}

private struct FirstDetailEnvironment {
  var effect: () -> Effect<Void, Never>
}

private let firstDetailReducer = Reducer<FirstDetailState, FirstDetailAction, FirstDetailEnvironment>
{ state, action, env in
  switch action {
  case .performEffect:
    return env.effect()
      .map { _ in FirstDetailAction.didPerformEffect }
      .eraseToEffect()

  case .didPerformEffect:
    return .none
  }
}

// MARK: - SecondDetail component

private struct SecondDetailState: Equatable {}

private enum SecondDetailAction: Equatable {
  case performEffect
  case didPerformEffect
}

private struct SecondDetailEnvironment {
  var effect: () -> Effect<Void, Never>
}

private let secondDetailReducer = Reducer<SecondDetailState, SecondDetailAction, SecondDetailEnvironment>
{ state, action, env in
  switch action {
  case .performEffect:
    return env.effect()
      .map { _ in SecondDetailAction.didPerformEffect }
      .eraseToEffect()

  case .didPerformEffect:
    return .none
  }
}