import UIKit


/// A type that provides support for toggling compound attributes in an attributed string.
///
/// When you want to represent an attribute that does not have a 1-1 correspondence with a standard
/// attribute, it is useful to have a virtual attribute. 
/// Toggling this attribute would also toggle the attributes for its defined style.
///
protocol AttributeFormatter {

    var elementType: Libxml2.StandardElementType { get }
    /// Attributes to be used the Content Placeholder, when / if needed.
    ///
    var placeholderAttributes: [String: Any]? { get }

    /// Toggles an attribute in the specified range of a text storage, and returns the new 
    /// Selected Range. This is required because, in several scenarios, we may need to add a "Zero Width Space",
    /// just to get the style to render properly.
    ///
    /// - Parameters:
    ///     - text: Text that should be formatted.
    ///     - range: Segment of text which format should be toggled.
    ///
    @discardableResult func toggle(in text: NSMutableAttributedString, at range: NSRange) -> NSRange?

    /// Checks if the attribute is present in a given Attributed String at the specified index.
    ///
    func present(in text: NSAttributedString, at index: Int) -> Bool

    /// Apply the compound attributes to the provided attributes dictionary.
    ///
    /// - Parameter attributes: the original attributes to apply to
    /// - Returns: the resulting attributes dictionary
    ///
    func apply(to attributes: [String: Any]) -> [String: Any]

    /// Remove the compound attributes from the provided list.
    ///
    /// - Parameter attributes: the original attributes to remove from
    /// - Returns: the resulting attributes dictionary
    ///
    func remove(from attributes: [String: Any]) -> [String: Any]

    /// Checks if the attribute is present in a dictionary of attributes.
    ///
    func present(in attributes: [String: AnyObject]) -> Bool

    func applicationRange(for range: NSRange, in text: NSAttributedString) -> NSRange
}


// MARK: - Default Implementations
//
extension AttributeFormatter {

    /// Indicates whether the Formatter's Attributes are present in a given string, at a specified Index.
    ///
    func present(in text: NSAttributedString, at index: Int) -> Bool {
        let safeIndex = max(min(index, text.length - 1), 0)
        let attributes = text.attributes(at: safeIndex, effectiveRange: nil) as [String : AnyObject]
        return present(in: attributes)
    }

}


// MARK: - Private Helpers
//
private extension AttributeFormatter {

    /// The string to be used when adding attributes to an empty line.
    ///
    func placeholderForEmptyLine(using attributes: [String: Any]?) -> NSAttributedString {
        return NSAttributedString(string: StringConstants.zeroWidthSpace, attributes: attributes)
    }

    /// Helper that indicates whether if we should format the specified range, or not. 
    /// -   Note: For convenience reasons, whenever the Text is empty, this helper will return *true*.
    ///
    func shouldApplyAttributes(to text: NSAttributedString, at range: NSRange) -> Bool {
        guard text.length > 0 else {
            return true
        }

        return present(in: text, at: range.location) == false
    }

    /// Applies the Formatter's Attributes into a given string, at the specified range.
    ///
    func applyAttributes(to string: NSMutableAttributedString, at range: NSRange) {
        let currentAttributes = string.attributes(at: range.location, effectiveRange: nil)
        let attributes = apply(to: currentAttributes)
        string.addAttributes(attributes, range: range)
    }

    /// Removes the Formatter's Attributes from a given string, at the specified range.
    ///
    func removeAttributes(from string: NSMutableAttributedString, at range: NSRange) {
        let currentAttributes = string.attributes(at: range.location, effectiveRange: nil)
        let attributes = remove(from: currentAttributes)
        string.addAttributes(attributes, range: range)
    }
}


// MARK: - Character Attribute Formatter
//
protocol CharacterAttributeFormatter: AttributeFormatter {
}

extension CharacterAttributeFormatter {

    var placeholderAttributes: [String : Any]? { return nil }

    func applicationRange(for range: NSRange, in text: NSAttributedString) -> NSRange {
        return range
    }

    /// Toggles the Attribute Format, into a given string, at the specified range.
    ///
    @discardableResult
    func toggle(in text: NSMutableAttributedString, at range: NSRange) -> NSRange? {
        guard range.location < text.length else {
            return range
        }

        if shouldApplyAttributes(to: text, at: range) {
            applyAttributes(to: text, at: range)
        } else {
            removeAttributes(from: text, at: range)
        }
        return range
    }
}


// MARK: - Paragraph Attribute Formatter
//
protocol ParagraphAttributeFormatter: AttributeFormatter {
}

extension ParagraphAttributeFormatter {

    func applicationRange(for range: NSRange, in text: NSAttributedString) -> NSRange {
        return text.paragraphRange(for: range)
    }

    /// Toggles an attribute in the specified range of a text storage, and returns the new Selected Range.
    ///
    /// - Note: Whenever either the application paragraph is empty, or the entire storage is empty,
    ///   we'll need to insert a placeholder (Zero Width String). Reason why? Because some formatters
    ///   (TextList / Blockquote) need to display a custom UI, even when there is no content to display.
    ///   In those scenarios, TextView's TypingAttributes just don't do the trick.
    ///
    /// - Note: For the reasons mentioned above, the first thing we'll do is to determine if the attribute should
    ///   be applied or not. Order of events is important. 
    ///   Why? because we *may need* to insert an empty string placeholder, and this operation may alter this result!
    ///
    @discardableResult
    func toggle(in text: NSMutableAttributedString, at range: NSRange) -> NSRange? {
        let shouldApply = shouldApplyAttributes(to: text, at: range)
        var rangeToApply = applicationRange(for: range, in: text)
        var newSelectedRange: NSRange?

        if rangeToApply.length == 0 || text.length == 0 {
            let placeholder = placeholderForEmptyLine(using: placeholderAttributes)
            text.insert(placeholder, at: rangeToApply.location)
            newSelectedRange = NSRange(location: text.length, length: 0)
            rangeToApply = NSMakeRange(text.length - 1, 1)
        }

        if shouldApply {
            applyAttributes(to: text, at: rangeToApply)
        } else {
            removeAttributes(from: text, at: rangeToApply)
        }

        return newSelectedRange
    }
}
