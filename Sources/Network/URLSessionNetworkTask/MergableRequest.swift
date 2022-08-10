//  Copyright © 2022 BergerBytes LLC. All rights reserved.
//
//  Permission to use, copy, modify, and/or distribute this software for any
//  purpose with or without fee is hereby granted, provided that the above
//  copyright notice and this permission notice appear in all copies.
//
//  THE SOFTWARE IS PROVIDED  AS IS AND THE AUTHOR DISCLAIMS ALL WARRANTIES
//  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
//  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
//  SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
//  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
//  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
//  IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

import Foundation

/// A Network task that should be merged if the same request is found already queued.
public protocol MergableRequest: QueueableTask {
    var delegate: MulticastDelegate<RequestDelegate> { get }
    var requestIdentifier: RequestIdentifier? { get }

    /// Check for wether or this task should be merged with the provided task.
    /// - Parameter task: The task to merge with.
    /// - Returns: Bool True if tasks should be merged.
    func shouldBeMerged(with task: MergableRequest) -> Bool
    func merge(into task: MergableRequest) throws
}
