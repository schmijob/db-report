Option Explicit

Private Const OL_FOLDER_INBOX As Long = 6
Private Const FIRST_RECEIVED_DATE As Date = #1/1/2022#
Private Const TARGET_PREFIX As String = "personalliste all"
Private Const REPO_ROOT As String = "C:\db-report"
Private Const SENDER_SAASMAIL As String = "saasmail@isgus.de"
Private Const SENDER_NOREPLY As String = "noreply@isgus.cloud"
Private Const PR_SMTP_ADDRESS As String = "http://schemas.microsoft.com/mapi/proptag/0x39FE001E"

Public Sub ExportPersonalListeAttachments()
    Dim fso As Object
    Dim inbox As Outlook.Folder
    Dim items As Outlook.Items
    Dim item As Object
    Dim mail As Outlook.MailItem
    Dim attachment As Outlook.Attachment
    Dim i As Long
    Dim savedCount As Long
    Dim existingCount As Long
    Dim failedCount As Long
    Dim folderMailCount As Long
    Dim scannedMailCount As Long
    Dim allowedSenderCount As Long
    Dim matchingAttachmentCount As Long
    Dim oldestReceived As Date
    Dim newestReceived As Date
    Dim fileName As String
    Dim targetPath As String
    Dim messageToken As String
    Dim parentFolder As String
    Dim exportFolder As String

    Set fso = CreateObject("Scripting.FileSystemObject")
    parentFolder = fso.BuildPath(fso.BuildPath(REPO_ROOT, ".worktrees"), "personalakte-backfill")
    exportFolder = fso.BuildPath(parentFolder, "raw")

    If Not fso.FolderExists(parentFolder) Then
        fso.CreateFolder parentFolder
    End If
    If Not fso.FolderExists(exportFolder) Then
        fso.CreateFolder exportFolder
    End If

    Set inbox = GetInboxZeusFolder()
    If inbox Is Nothing Then
        MsgBox "Could not find the 'Zeus' folder directly under Inbox.", vbExclamation
        Exit Sub
    End If

    Set items = inbox.Items.Restrict( _
        "[ReceivedTime] >= '" & Format$(FIRST_RECEIVED_DATE, "ddddd h:nn AMPM") & "'")
    items.Sort "[ReceivedTime]", False

    For Each item In items
        If TypeOf item Is Outlook.MailItem Then
            Set mail = item
            folderMailCount = folderMailCount + 1
            If oldestReceived = 0 Or mail.ReceivedTime < oldestReceived Then
                oldestReceived = mail.ReceivedTime
            End If
            If mail.ReceivedTime > newestReceived Then
                newestReceived = mail.ReceivedTime
            End If

            If mail.ReceivedTime >= FIRST_RECEIVED_DATE Then
                scannedMailCount = scannedMailCount + 1
            End If

            If mail.ReceivedTime >= FIRST_RECEIVED_DATE And IsAllowedSender(mail) Then
                allowedSenderCount = allowedSenderCount + 1
                messageToken = SafeFileToken(mail.EntryID)

                For i = 1 To mail.Attachments.Count
                    Set attachment = mail.Attachments.Item(i)

                    If IsPersonalListeCsv(attachment.FileName) Then
                        matchingAttachmentCount = matchingAttachmentCount + 1
                        fileName = Format$(mail.ReceivedTime, "yyyymmdd_hhnnss") & _
                                   "_" & messageToken & "_A" & Format$(i, "00") & _
                                   "__" & SafeFileName(attachment.FileName)
                        targetPath = fso.BuildPath(exportFolder, fileName)

                        If fso.FileExists(targetPath) Then
                            existingCount = existingCount + 1
                        Else
                            On Error Resume Next
                            attachment.SaveAsFile targetPath
                            If Err.Number = 0 Then
                                savedCount = savedCount + 1
                            Else
                                failedCount = failedCount + 1
                                Err.Clear
                            End If
                            On Error GoTo 0
                        End If
                    End If
                Next i
            End If
        End If
    Next item

    MsgBox "Attachment export finished." & vbCrLf & _
           "Folder: " & inbox.FolderPath & vbCrLf & _
           "Mail in date range: " & folderMailCount & vbCrLf & _
           "Oldest message in range: " & IIf(oldestReceived = 0, "none", Format$(oldestReceived, "yyyy-mm-dd")) & vbCrLf & _
           "Newest message in range: " & IIf(newestReceived = 0, "none", Format$(newestReceived, "yyyy-mm-dd")) & vbCrLf & _
           "Mail from 2022 onward: " & scannedMailCount & vbCrLf & _
           "Allowed senders: " & allowedSenderCount & vbCrLf & _
           "Matching CSV attachments: " & matchingAttachmentCount & vbCrLf & _
           "Saved: " & savedCount & vbCrLf & _
           "Already present: " & existingCount & vbCrLf & _
           "Failed: " & failedCount & vbCrLf & _
           "Folder: " & exportFolder, vbInformation
End Sub

Private Function GetInboxZeusFolder() As Outlook.Folder
    Dim rootInbox As Outlook.Folder

    Set rootInbox = Application.Session.GetDefaultFolder(OL_FOLDER_INBOX)
    On Error Resume Next
    Set GetInboxZeusFolder = rootInbox.Folders("Zeus")
    On Error GoTo 0
End Function

Private Function IsAllowedSender(ByVal mail As Outlook.MailItem) As Boolean
    Dim senderAddress As String
    senderAddress = LCase$(Trim$(GetSenderSmtpAddress(mail)))

    IsAllowedSender = (senderAddress = SENDER_SAASMAIL) Or _
                      (senderAddress = SENDER_NOREPLY)
End Function

Private Function GetSenderSmtpAddress(ByVal mail As Outlook.MailItem) As String
    Dim senderAddress As String
    Dim exchangeUser As Outlook.ExchangeUser

    On Error Resume Next
    senderAddress = mail.PropertyAccessor.GetProperty(PR_SMTP_ADDRESS)
    On Error GoTo 0

    If Len(Trim$(senderAddress)) = 0 Then
        senderAddress = mail.SenderEmailAddress
    End If

    If InStr(1, senderAddress, "/", vbTextCompare) > 0 Then
        On Error Resume Next
        Set exchangeUser = mail.Sender.GetExchangeUser
        If Not exchangeUser Is Nothing Then
            senderAddress = exchangeUser.PrimarySmtpAddress
        End If
        On Error GoTo 0
    End If

    GetSenderSmtpAddress = senderAddress
End Function

Private Function IsPersonalListeCsv(ByVal attachmentName As String) As Boolean
    Dim normalized As String
    normalized = LCase$(Trim$(attachmentName))

    IsPersonalListeCsv = _
        (Left$(normalized, Len(TARGET_PREFIX)) = TARGET_PREFIX) And _
        (Right$(normalized, 4) = ".csv")
End Function

Private Function SafeFileName(ByVal fileName As String) As String
    Dim invalidChars As Variant
    Dim ch As Variant

    invalidChars = Array("\", "/", ":", "*", "?", Chr$(34), "<", ">", "|")
    For Each ch In invalidChars
        fileName = Replace$(fileName, CStr(ch), "_")
    Next ch

    SafeFileName = Trim$(fileName)
End Function

Private Function SafeFileToken(ByVal entryId As String) As String
    Dim token As String
    token = Right$(entryId, 10)

    If Len(token) = 0 Then token = "noid"
    SafeFileToken = SafeFileName(token)
End Function
