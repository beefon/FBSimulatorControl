/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

import FBDeviceControl
import FBSimulatorControl
import Foundation

extension CommandResultRunner {
  static func unimplementedActionRunner(_ action: Action, target: FBiOSTarget, format: FBiOSTargetFormat) -> Runner {
    let (eventName, maybeSubject) = action.reportable
    var actionMessage = eventName.rawValue
    if let subject = maybeSubject {
      actionMessage += " \(subject.description)"
    }
    let message = "Action \(actionMessage) is unimplemented for target \(format.format(target))"
    return CommandResultRunner(result: CommandResult.failure(message))
  }
}

struct iOSActionProvider {
  let context: iOSRunnerContext<(Action, FBiOSTarget, iOSReporter)>

  func makeRunner() -> Runner? {
    let (action, target, reporter) = context.value

    switch action {
    case .uninstall(let appBundleID):
      return FutureRunner(reporter, .uninstall, FBEventReporterSubject(string: appBundleID), target.uninstallApplication(withBundleID: appBundleID))
    case .coreFuture(let action):
      let future = action.run(with: target, consumer: reporter.reporter.writer, reporter: reporter.reporter)
      return FutureRunner(reporter, action.eventName, action.subject, future)
    case .record(.start(let filePath)):
      return FutureRunner(reporter, nil, RecordSubject(.start(filePath)), target.startRecording(toFile: filePath))
    case .record(.stop):
      return FutureRunner(reporter, nil, RecordSubject(.stop), target.stopRecording())
    case .stream(let configuration, let output):
      return FutureRunner(reporter, .stream, configuration.subject, target.startStreaming(configuration: configuration, output: output))
    case .terminate(let bundleID):
      return FutureRunner(reporter, .terminate, FBEventReporterSubject(string: bundleID), target.killApplication(withBundleID: bundleID))
    default:
      return nil
    }
  }
}

struct FutureRunner<T: AnyObject>: Runner {
  let reporter: iOSReporter
  let name: EventName?
  let subject: EventReporterSubject
  let future: FBFuture<T>

  init(_ reporter: iOSReporter, _ name: EventName?, _ subject: EventReporterSubject, _ future: FBFuture<T>) {
    self.reporter = reporter
    self.name = name
    self.subject = subject
    self.future = future
  }

  func run() -> CommandResult {
    do {
      if let name = self.name {
        reporter.report(name, .started, subject)
      }
      let value = try future.await()
      if let name = self.name {
        reporter.report(name, .ended, subject)
      }
      var continuations: [FBiOSTargetContinuation] = []
      if let continuation = value as? FBiOSTargetContinuation, continuation.completed != nil {
        continuations.append(continuation)
      }
      return CommandResult(outcome: .success(nil), continuations: continuations)
    } catch let error as NSError {
      return .failure(error.description)
    } catch let error as JSONError {
      return .failure(error.description)
    } catch {
      return .failure("Unknown Error")
    }
  }
}

struct SimpleRunner: Runner {
  let reporter: iOSReporter
  let name: EventName?
  let subject: EventReporterSubject
  let action: () throws -> Void

  init(_ reporter: iOSReporter, _ name: EventName?, _ subject: EventReporterSubject, _ action: @escaping () throws -> Void) {
    self.reporter = reporter
    self.name = name
    self.subject = subject
    self.action = action
  }

  func run() -> CommandResult {
    do {
      if let name = self.name {
        reporter.report(name, .started, subject)
      }
      try action()
      if let name = self.name {
        reporter.report(name, .ended, subject)
      }
      return CommandResult(outcome: .success(nil), continuations: [])
    } catch let error as NSError {
      return .failure(error.description)
    } catch let error as JSONError {
      return .failure(error.description)
    } catch {
      return .failure("Unknown Error")
    }
  }
}
