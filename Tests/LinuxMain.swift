/// LinuxMain.swift
///
/// Copyright 2018, The Silt Language Project.
///
/// This project is released under the MIT license, a copy of which is
/// available in the repository.

import XCTest
@testable import InnerCoreSupportTests

#if !os(macOS)
XCTMain([
  BitVectorSpec.allTests
])
#endif
