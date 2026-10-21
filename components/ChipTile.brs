' ChipTile — focusable label tile for the single-row RowLists (season chips,
' movie action buttons). Same field plumbing as PosterTile: RowList feeds the
' ContentNode through itemContent and drives focus through itemHasFocus /
' rowHasFocus. Text is read from itemContent.title.

sub init()
    m.face = m.top.FindNode("chipFace")
    m.text = m.top.FindNode("chipText")

    t = Theme()
    m.text.color = t.textSecondary

    m.top.ObserveField("itemContent", "onItemContentChanged")
    m.top.ObserveField("itemHasFocus", "onItemHasFocusChanged")
    m.top.ObserveField("rowHasFocus", "onRowHasFocusChanged")
end sub

' Every inbound field change re-applies the whole look from the tile's current
' field values. RowList recycles item components for new cells and content
' swaps, and rowHasFocus/itemHasFocus only fire on value *changes* — on a
' recycle nothing may change except itemContent, so unless the look is rebuilt
' there a tile carries stale dimming (opacity 0.55) into a fresh RowList on
' another screen/media.
sub UpdateLook()
    t = Theme()
    if m.top.itemHasFocus
        m.face.color = t.itemFace
        m.text.color = t.textPrimary
    else if IsActive() then
        ' The chip that stands for the current state of its group is painted in
        ' the accent whether or not it has the focus. The focus ring answers
        ' "where am I", which is not the same question as "which one is
        ' selected" — and on a section tab the two come apart the moment the
        ' user walks away from the chips.
        m.face.color = t.accentDim
        m.text.color = t.accent
    else
        m.face.color = t.tileFace
        m.text.color = t.textSecondary
    end if
    if m.top.rowHasFocus then m.top.opacity = 1.0 else m.top.opacity = 0.55
end sub

' Whether this chip's content carries the active marker. HasField, because
' not every user of this tile builds ChipContent nodes: reading a field the
' node does not have is a runtime error, not a false, so the question has to
' be asked before it is answered.
function IsActive() as boolean
    content = m.top.itemContent
    if content = invalid then return false
    if not content.HasField("active") then return false
    return content.active = true
end function

sub onItemContentChanged()
    content = m.top.itemContent
    if content = invalid then return
    m.text.text = content.title

    if content.width <> invalid
        m.face.width = content.width
        m.text.width = content.width - 8
    end if

    if content.chipHeight <> invalid
        m.face.height = content.height
        m.text.height = content.height - 8
    end if

    ' The active marker lives on the content node, so the observation is made
    ' ON THAT NODE — ObserveField watches a field of the node it is called on,
    ' and the tile has no field of that name. Only when the node has the field
    ' at all: observing a field that is not there is an error, not a no-op.
    if content.HasField("active") then content.ObserveField("active", "onActiveChanged")

    UpdateLook()
end sub

' The selected chip changed without the content changing: the same chip row
' now stands for a different state. Repaint.
sub onActiveChanged()
    UpdateLook()
end sub

sub onItemHasFocusChanged()
    UpdateLook()
end sub

sub onRowHasFocusChanged()
    UpdateLook()
end sub
