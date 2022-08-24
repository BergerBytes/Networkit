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

/// A task that should be merged if the same task is found already queued.
public protocol MergableTask: QueueableTask {
    /// Check for wether or this task should be merged with the provided task.
    /// - Parameter task: The task to merge with.
    /// - Returns: Bool True if tasks should be merged.
    #if compiler(>=5.7)
        func shouldBeMerged(with task: some MergableTask) -> Bool
        func merge(into task: some MergableTask) throws
    #else
        func shouldBeMerged(with task: MergableTask) -> Bool
        func merge(into task: MergableTask) throws
    #endif
}
