import SwiftUI

/// `.focused` takes a non-optional binding. This keeps the optionality out of the view tree;
/// the branch is fixed for the host's lifetime, so identity never flips under it. Shared by
/// `InputBar` and `Field` — both let a caller open with the keyboard already up, or not care.
struct OptionalFocus: ViewModifier {
    let focus: FocusState<Bool>.Binding?

    func body(content: Content) -> some View {
        if let focus {
            content.focused(focus)
        } else {
            content
        }
    }
}
