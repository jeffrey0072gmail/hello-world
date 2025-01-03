<#
.SYNOPSIS
    This script copies a SQL Server database.

.DESCRIPTION
    1. Displays an introduction message first.
    2. Prompts for the source and target database names.
    3. Checks if the target database exists and prompts to drop it if it does.
    4. Connects to a specified SQL Server instance using the provided credentials.
    5. Detaches the source DB, copies its data files, then reattaches both source and target DBs.

.PARAMETER sourceDbName
    The name of the source database to copy.

.PARAMETER targetDbName
    The name of the new copied database.

.NOTES
    - Update $instanceName, $username, and $password placeholders in the script.
    - Requires the SqlServer PowerShell module.
    - Ensure you have the required permissions on the target SQL Server instance.

.EXAMPLE
    .\Copy-Database.ps1 -sourceDbName db1 -targetDbName db2
#>

param (
    [string]$sourceDbName,
    [string]$targetDbName
)

Write-Host "--------------------------------------------------------"
Write-Host " Welcome to the Copy-Database script!"
Write-Host " This script copies a SQL Server database to a new name."
Write-Host " You can change the SQL Server instance name, username, and password in the script."
Write-Host " Usage: .\Copy-Database.ps1 -sourceDbName <SourceDatabase> -targetDbName <TargetDatabase>"
Write-Host "--------------------------------------------------------"
Write-Host ""

# Check if the SqlServer module is installed
if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    Write-Host "SqlServer module not found. Installing..."
    Install-Module -Name SqlServer -AllowClobber -Force
}

# Import the SqlServer module
Import-Module SqlServer -ErrorAction SilentlyContinue

# Set your SQL Server instance name and credentials
$instanceName = "ex-jwang"
$username     = "sa"
$password     = "blue"

Write-Host "Attempting to connect to SQL Server instance '$instanceName'..."

# Build the connection string
$connectionString = "Server=$instanceName;Database=master;User ID=$username;Password=$password;Encrypt=True;TrustServerCertificate=True"

# Check if the connection to SQL Server is successful
try {
    Invoke-Sqlcmd -ConnectionString $connectionString -Query "SELECT 1" -ErrorAction Stop
    Write-Host "Successfully connected to SQL Server instance '$instanceName'."
} catch {
    Write-Host "Failed to connect to SQL Server instance '$instanceName'. Exiting script."
    exit
}

# Prompt for required parameters
if (-not $sourceDbName) {
    $sourceDbName = Read-Host "Enter the source database name"
}

if (-not $targetDbName) {
    $targetDbName = Read-Host "Enter the target database name"
}

$sourceDetached = $false
try {
    # 1) Check if source DB exists
    $checkDbQuery = "
        SELECT CASE WHEN db_id('$sourceDbName') IS NOT NULL THEN 1 ELSE 0 END AS ExistsFlag;
    "
    $sourceExists = Invoke-Sqlcmd -ConnectionString $connectionString -Query $checkDbQuery |
        Select-Object -ExpandProperty ExistsFlag

    if ($sourceExists -eq 0) {
        Write-Host "Source database '$sourceDbName' does not exist. Exiting script."
        exit
    }
    
    # 2) Get the physical file names for the source database
    $fileQuery = "
        SELECT physical_name
        FROM sys.master_files
        WHERE database_id = db_id('$sourceDbName');
    "
    $fileNames = Invoke-Sqlcmd -ConnectionString $connectionString -Query $fileQuery

    $sourceMdf = $fileNames | Where-Object { $_.physical_name -like "*.mdf" } | Select-Object -ExpandProperty physical_name
    $sourceLdf = $fileNames | Where-Object { $_.physical_name -like "*.ldf" } | Select-Object -ExpandProperty physical_name
    $targetMdf = $sourceMdf -replace [regex]::Escape($sourceDbName), $targetDbName
    $targetLdf = $sourceLdf -replace [regex]::Escape($sourceDbName), $targetDbName

    # 3) Check if target DB exists
    $checkDbQuery = "
        SELECT CASE WHEN db_id('$targetDbName') IS NOT NULL THEN 1 ELSE 0 END AS ExistsFlag;
    "
    $targetExists = Invoke-Sqlcmd -ConnectionString $connectionString -Query $checkDbQuery |
        Select-Object -ExpandProperty ExistsFlag

    if ($targetExists -eq 1) {
        # Target database exists, prompt the user
        $userResponse = Read-Host "Target database '$targetDbName' already exists. Drop the target DB if it exists? (Y/N)"
        if ($userResponse -eq 'Y') {
            Write-Host "Dropping existing target database '$targetDbName'..."
            Invoke-Sqlcmd -ConnectionString $connectionString -Query "
                ALTER DATABASE [$targetDbName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
                DROP DATABASE [$targetDbName];
            "
            Write-Host "Dropped target database '$targetDbName'."
        } else {
            Write-Host "Operation cancelled by user."
            exit
        }
    }

    # 4) Detach the source database
    Write-Host "Detaching source database '$sourceDbName'..."
    Invoke-Sqlcmd -ConnectionString $connectionString -Query "
        ALTER DATABASE [$sourceDbName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        EXEC sp_detach_db [$sourceDbName];
    "
    Write-Host "Detached source database '$sourceDbName'."
    $sourceDetached = $true

    # 5) Copy the database files to create the target database
    Write-Host "Copying database files to create '$targetDbName'..."
    Copy-Item -Path $sourceMdf -Destination $targetMdf -Force
    Copy-Item -Path $sourceLdf -Destination $targetLdf -Force
    Write-Host "Copied database files for '$targetDbName'."

    # 6) Attach the newly copied database
    Write-Host "Attaching target database '$targetDbName'..."
    Invoke-Sqlcmd -ConnectionString $connectionString -Query "
        CREATE DATABASE [$targetDbName]
        ON (FILENAME = N'$targetMdf'),
           (FILENAME = N'$targetLdf')
        FOR ATTACH;
    "
    Write-Host "Attached target database '$targetDbName'."

    Write-Host "--------------------------------------------------------"
    Write-Host "Database '$targetDbName' has been successfully created by copying '$sourceDbName'."
}
catch {
    Write-Host "An error occurred:"
    Write-Host $_.Exception.Message
}
finally {
    if ($sourceDetached) {
        # Ensure the source database is re-attached
        try {
            Invoke-Sqlcmd -ConnectionString $connectionString -Query "
                CREATE DATABASE [$sourceDbName]
                ON (FILENAME = N'$sourceMdf'),
                   (FILENAME = N'$sourceLdf')
                FOR ATTACH;
            " -ErrorAction SilentlyContinue
            Write-Host "Ensured source database '$sourceDbName' is re-attached."
        } catch {
            Write-Host "Failed to re-attach source database '$sourceDbName'."
        }

        # Attempt to set the source DB to multi-user
        try {
            Invoke-Sqlcmd -ConnectionString $connectionString -Query "
                ALTER DATABASE [$sourceDbName] SET MULTI_USER;
            " -ErrorAction SilentlyContinue
        } catch {}
    }
}