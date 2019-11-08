/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

import FBSimulatorControl
@testable import FBSimulatorControlKit
import XCTest

@objc class FBSimulatorControlKitTestsNSObject: NSObject {
}

struct Fixtures {
  static var application: FBApplicationBundle {
    return FBApplicationBundle.xcodeSimulator()
  }

  static var binary: FBBinaryDescriptor {
    return try! FBBinaryDescriptor.binary(withPath: "/bin/launchctl")
  }

  static var photoPath: String {
    return Bundle(for: FBSimulatorControlKitTestsNSObject.self).path(forResource: "photo0", ofType: "png")!
  }

  static var photoDiagnostic: FBDiagnostic {
    return FBDiagnosticBuilder().updatePath(photoPath).build()
  }

  static var videoPath: String {
    return Bundle(for: FBSimulatorControlKitTestsNSObject.self).path(forResource: "video0", ofType: "mp4")!
  }

  static var videoDiagnostic: FBDiagnostic {
    return FBDiagnosticBuilder().updatePath(videoPath).build()
  }

  static var testBundlePath: String {
    return Bundle.main.bundlePath
  }
}

extension CreationSpecification {
  static var empty: CreationSpecification {
    return CreationSpecification.individual(
      IndividualCreationConfiguration(os: nil, model: nil, auxDirectory: nil)
    )
  }

  static var iOS9CreationSpecification: CreationSpecification {
    return CreationSpecification.individual(
      IndividualCreationConfiguration(os: .nameiOS_9_0, model: nil, auxDirectory: nil)
    )
  }

  static var iPhone6Configuration: CreationSpecification {
    return CreationSpecification.individual(
      IndividualCreationConfiguration(os: nil, model: .modeliPhone6, auxDirectory: nil)
    )
  }

  static var auxDirectoryConfiguration: CreationSpecification {
    return CreationSpecification.individual(
      IndividualCreationConfiguration(os: nil, model: nil, auxDirectory: "/usr/bin")
    )
  }

  static var compoundConfiguration0: CreationSpecification {
    return CreationSpecification.individual(
      IndividualCreationConfiguration(os: .nameiOS_9_3, model: .modeliPhone6S, auxDirectory: nil)
    )
  }

  static var compoundConfiguration1: CreationSpecification {
    return CreationSpecification.individual(
      IndividualCreationConfiguration(os: .nameiOS_10_0, model: .modeliPadAir2, auxDirectory: nil)
    )
  }
}