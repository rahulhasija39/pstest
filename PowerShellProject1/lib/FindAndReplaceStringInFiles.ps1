# This method is used to find a string in a set of files belong to a folder and replace it with a given string.
function FindAndReplace ([string]$folderName, [string]$stringToFind, [string]$stringToReplace, [string]$filesToFind)
{
    Write-Host 'FindAndReplace: Folder:' $folderName
    cd $folderName

    $count = 0
    (findstr -spinm /c:$stringToFind $filesToFind) | foreach-object {
        $file = $_
        $content = (get-content $file)
        $content = $content | foreach-object {
        ($_ -replace $stringToFind, $stringToReplace)
        }
        $count++
        Write-Host 'FindAndReplace: '$count ': Processing file ' $file
        $content | set-content -path $file
    }
}
