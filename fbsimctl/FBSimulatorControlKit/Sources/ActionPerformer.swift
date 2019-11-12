/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

import FBControlCore
import Foundation

/**
 Defines the Output of running a Command.
 */
public struct CommandResult {
  let outcome: CommandOutcome
  let continuations: [FBiOSTargetContinuation]

  static func success(_ subject: EventReporterSubject?) -> CommandResult {
    return CommandResult(outcome: .success(subject), continuations: [])
  }

  static func failure(_ message: String) -> CommandResult {
    return CommandResult(outcome: .failure(message), continuations: [])
  }

  func append(_ second: CommandResult) -> CommandResult {
    return CommandResult(
      outcome: outcome.append(second.outcome),
      continuations: continuations + second.continuations
    )
  }
}

@objc class CommandResultBox: NSObject {
  let value: CommandResult

  init(value: CommandResult) {
    self.value = value
  }
}

/**
 Runs an Action, yielding a result
 */
protocol ActionPerformer {
  var configuration: Configuration { get }
  var query: FBiOSTargetQuery { get }

  func runnerContext(_ reporter: EventReporter) -> iOSRunnerContext<()>
  func future(reporter: EventReporter, action: Action, queryOverride: FBiOSTargetQuery?) -> FBFuture<CommandResultBox>
}

/**
 Defines the Outcome of runnic a Command.
 */
public enum CommandOutcome: CustomStringConvertible, CustomDebugStringConvertible {
  case success(EventReporterSubject?)
  case failure(String)

  func append(_ second: CommandOutcome) -> CommandOutcome {
    switch (self, second) {
    case (.success(.some(let leftSubject)), .success(.some(let rightSubject))):
      return .success(leftSubject.append(rightSubject))
    case (.success(.some(let leftSubject)), .success(.none)):
      return .success(leftSubject)
    case (.success(.none), .success(.some(let rightSubject))):
      return .success(rightSubject)
    case (.success, .success):
      return .success(nil)
    case (.success, .failure(let secondString)):
      return .failure(secondString)
    case (.failure(let firstString), .success):
      return .failure(firstString)
    case (.failure(let firstString), .failure(let secondString)):
      return .failure("\(firstString)\n\(secondString)")
    }
  }

  public var description: String {
    switch self {
    case .success: return "Success"
    case .failure(let string): return "Failure '\(string)'"
    }
  }

  public var debugDescription: String {
    return description
  }
}
