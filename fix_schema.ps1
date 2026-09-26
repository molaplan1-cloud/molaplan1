$c = [System.IO.File]::ReadAllText("C:\Users\Administrator\molaplan\molaplan\supabase\schema.sql")
$c = $c -replace ';;', ';'
[System.IO.File]::WriteAllText("C:\Users\Administrator\molaplan\molaplan\supabase\schema.sql", $c)
Write-Host "Done"