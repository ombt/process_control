#
# remove item from environment
#
ifrm <- function(x, env=globalenv())
{
    if (exists(x, envir=env))
    {
        rm(list=x, envir=env);
    }
}
#
# for read.csv the possible colClasses are: logical, integer, numeric, complex,
# character, raw or factor, Date or POSIXct. you can also provide a function to 
# perform translation from character to the chosen type.
# 
# the file types as of now are: u01, u03, mpr, mai, and crb.
#
# function reads CSV data for MountQualityTrace.csv file. you have the
# option to read all columns and all records, or to specify which columns
# should be included or not included. you can also specify the number of
# records to read. the default is nrows=-1, or all records. with null_cols=c()
# and not_null_cols=c(), then all columns are read in.
#
read_MountQualityTrace <- function(csv_path=".", 
                                   fname = "MountQualityTrace.csv",
                                   null_cols=c(), 
                                   not_null_cols=c(), 
                                   nrows=-1)
{
    #
    # default column classes for [MountQualityTrace] U03 section
    #
    # FID - integer
    # B - integer
    # IDNUM - integer
    # TURN - integer
    # MS - integer
    # TS - integer
    # FAdd - integer
    # FSAdd - integer
    # FBLKCode - character
    # FBLKSerial - character
    # NHAdd - integer
    # NCAdd - integer
    # NBLKCode - character
    # NBLKSerial - character
    # ReelID - character
    # F - integer
    # RCGX - numeric
    # RCGY - numeric
    # RCGA - numeric
    # TCX - numeric
    # TCY - numeric
    # MPosiRecX - numeric
    # MPosiRecY - numeric
    # MPosiRecA - numeric
    # MPosiRecZ - numeric
    # THMAX - numeric
    # THAVE - numeric
    # MNTCX - numeric
    # MNTCY - numeric
    # MNTCA - numeric
    # TLX - numeric
    # TLY - numeric
    # InspectArea - integer
    # DIDNUM - integer
    # DS - integer
    # DispenseID - character
    # PARTS integer
    # WarpZ - numeric
    #
    character_col_classes = c(
        "FBLKCode", 
        "FBLKSerial", 
        "NBLKCode", 
        "NBLKSerial", 
        "ReelID", 
        "DispenseID"
    )
    integer_col_classes = c(
        "FID", 
        "B", 
        "IDNUM", 
        "TURN", 
        "MS", 
        "TS",
        "FAdd", 
        "FSAdd", 
        "NHAdd", 
        "NCAdd", 
        "F", 
        "InspectArea", 
        "DIDNUM", 
        "DS", 
        "PARTS"
    )
    numeric_col_classes = c(
        "RCGX", 
        "RCGY", 
        "RCGA", 
        "TCX", 
        "TCY", 
        "MPosiRecX",
        "MPosiRecY", 
        "MPosiRecA", 
        "MPosiRecZ", 
        "THMAX",
        "THAVE", 
        "MNTCX", 
        "MNTCY", 
        "MNTCA", 
        "TLX", 
        "TLY", 
        "WarpZ"
    )
    #
    if (nchar(as.character(fname)) <= 0)
    {
        fname = "MountQualityTrace.csv"
    }
    path = paste(csv_path, fname, sep = "/")
    #
    headset = read.csv(path, header = TRUE, sep="\t", nrows = 10)
    classes = sapply(headset, class)
    #
    classes[names(classes) %in% character_col_classes] = "character"
    classes[names(classes) %in% integer_col_classes] = "integer"
    classes[names(classes) %in% numeric_col_classes] = "numeric"
    #
    all_classes = c(character_col_classes, 
                    integer_col_classes, 
                    numeric_col_classes)
    classes[!(names(classes) %in% all_classes)] = "character"
    #
    if (length(null_cols) > 0)
    {
        classes[names(classes) %in% null_cols] = "NULL";
    }
    else if (length(not_null_cols) > 0)
    {
        classes[!(names(classes) %in% not_null_cols)] = "NULL";
    }
    #
    return(read.csv(path, header=TRUE, sep="\t", colClasses=classes, nrows=nrows))
}
#
read_BRecg <- function(csv_path=".", 
                       fname = "BRecg.csv",
                       null_cols=c(), 
                       not_null_cols=c(), 
                       nrows=-1)
{
    # BRecg.csv
    # FID - integer
    # IDNUM - integer
    # BRecX - numeric
    # BRecY - numeric
    integer_col_classes = c(
        "FID", 
        "IDNUM"
    )
    numeric_col_classes = c(
        "BRecX", 
        "BRecY"
    )
    #
    if (nchar(as.character(fname)) <= 0)
    {
        fname = "BRecg.csv"
    }
    path = paste(csv_path, fname, sep = "/")
    #
    headset = read.csv(path, header = TRUE, sep="\t", nrows = 10)
    classes = sapply(headset, class)
    #
    classes[names(classes) %in% integer_col_classes] = "integer"
    classes[names(classes) %in% numeric_col_classes] = "numeric"
    #
    all_classes = c(integer_col_classes, 
                    numeric_col_classes)
    classes[!(names(classes) %in% all_classes)] = "character"
    #
    if (length(null_cols) > 0)
    {
        classes[names(classes) %in% null_cols] = "NULL";
    }
    else if (length(not_null_cols) > 0)
    {
        classes[!(names(classes) %in% not_null_cols)] = "NULL";
    }
    #
    return(read.csv(path, header=TRUE, sep="\t", colClasses=classes, nrows=nrows))
}
#
read_Count <- function(csv_path=".", 
                       fname = "Count.csv",
                       null_cols=c(), 
                       not_null_cols=c(), 
                       nrows=-1)
{
    # Count.csv
    # FID - integer
    # NAME - character
    # VALUE - character
    character_col_classes = c(
        "NAME", 
        "VALUE"
    )
    integer_col_classes = c(
        "FID"
    )
    #
    if (nchar(as.character(fname)) <= 0)
    {
        fname = "Count.csv"
    }
    path = paste(csv_path, fname, sep = "/")
    #
    headset = read.csv(path, header = TRUE, sep="\t", nrows = 10)
    classes = sapply(headset, class)
    #
    classes[names(classes) %in% character_col_classes] = "character"
    classes[names(classes) %in% integer_col_classes] = "integer"
    #
    all_classes = c(character_col_classes, 
                    integer_col_classes)
    classes[!(names(classes) %in% all_classes)] = "character"
    #
    if (length(null_cols) > 0)
    {
        classes[names(classes) %in% null_cols] = "NULL";
    }
    else if (length(not_null_cols) > 0)
    {
        classes[!(names(classes) %in% not_null_cols)] = "NULL";
    }
    #
    return(read.csv(path, header=TRUE, sep="\t", colClasses=classes, nrows=nrows))
}
#
read_SBoard <- function(csv_path=".", 
                       fname = "SBoard.csv",
                       null_cols=c(), 
                       not_null_cols=c(), 
                       nrows=-1)
{
    # SBoard.csv
    # FID - integer
    # B - integer
    # SCode - character
    # SBcrStatus = integer
    character_col_classes = c(
        "SCode", 
        "SBcrStatus"
    )
    integer_col_classes = c(
        "FID",
        "B"
    )
    #
    if (nchar(as.character(fname)) <= 0)
    {
        fname = "SBoard.csv"
    }
    path = paste(csv_path, fname, sep = "/")
    #
    headset = read.csv(path, header = TRUE, sep="\t", nrows = 10)
    classes = sapply(headset, class)
    #
    classes[names(classes) %in% character_col_classes] = "character"
    classes[names(classes) %in% integer_col_classes] = "integer"
    #
    all_classes = c(character_col_classes, 
                    integer_col_classes)
    classes[!(names(classes) %in% all_classes)] = "character"
    #
    if (length(null_cols) > 0)
    {
        classes[names(classes) %in% null_cols] = "NULL";
    }
    else if (length(not_null_cols) > 0)
    {
        classes[!(names(classes) %in% not_null_cols)] = "NULL";
    }
    #
    return(read.csv(path, header=TRUE, sep="\t", colClasses=classes, nrows=nrows))
}
#
read_CycleTime <- function(csv_path=".", 
                       fname = "CycleTime.csv",
                       null_cols=c(), 
                       not_null_cols=c(), 
                       nrows=-1)
{
    # CycleTime.csv
    # FID
    # NAME
    # VALUE
    character_col_classes = c(
        "NAME", 
        "VALUE"
    )
    integer_col_classes = c(
        "FID"
    )
    #
    if (nchar(as.character(fname)) <= 0)
    {
        fname = "CycleTime.csv"
    }
    path = paste(csv_path, fname, sep = "/")
    #
    headset = read.csv(path, header = TRUE, sep="\t", nrows = 10)
    classes = sapply(headset, class)
    #
    classes[names(classes) %in% character_col_classes] = "character"
    classes[names(classes) %in% integer_col_classes] = "integer"
    #
    all_classes = c(character_col_classes, 
                    integer_col_classes)
    classes[!(names(classes) %in% all_classes)] = "character"
    #
    if (length(null_cols) > 0)
    {
        classes[names(classes) %in% null_cols] = "NULL";
    }
    else if (length(not_null_cols) > 0)
    {
        classes[!(names(classes) %in% not_null_cols)] = "NULL";
    }
    #
    return(read.csv(path, header=TRUE, sep="\t", colClasses=classes, nrows=nrows))
}
#
read_FID_DATA <- function(csv_path=".", 
                       fname = "FID_DATA.csv",
                       null_cols=c(), 
                       not_null_cols=c(), 
                       nrows=-1)
{
    # FID_DATA.csv
    # FID - integer
    # FTYPE - character
    # DATE - character
    # MACHINE - integer
    # LANE - integer
    # STAGE - integer
    # OUTPUT - integer
    # MJSID - character
    # LOTNAME - character
    # LOTNUMBER - character
    # SERIAL - character
    # PRODUCTID - character
    # PRODUCT - character
    character_col_classes = c(
        "FTYPE",
        "DATE",
        "MJSID",
        "LOTNAME",
        "LOTNUMBER",
        "SERIAL",
        "PRODUCTID",
        "PRODUCT"
    )
    integer_col_classes = c(
        "FID",
        "MACHINE",
        "LANE",
        "STAGE",
        "OUTPUT"
    )
    #
    if (nchar(as.character(fname)) <= 0)
    {
        fname = "FID_DATA.csv"
    }
    path = paste(csv_path, fname, sep = "/")
    #
    headset = read.csv(path, header = TRUE, sep="\t", nrows = 10)
    classes = sapply(headset, class)
    #
    classes[names(classes) %in% character_col_classes] = "character"
    classes[names(classes) %in% integer_col_classes] = "integer"
    #
    all_classes = c(character_col_classes, 
                    integer_col_classes)
    classes[!(names(classes) %in% all_classes)] = "character"
    #
    if (length(null_cols) > 0)
    {
        classes[names(classes) %in% null_cols] = "NULL";
    }
    else if (length(not_null_cols) > 0)
    {
        classes[!(names(classes) %in% not_null_cols)] = "NULL";
    }
    #
    return(read.csv(path, header=TRUE, sep="\t", colClasses=classes, nrows=nrows))
}
#
read_FILENAME_TO_IDS <- function(csv_path=".", 
                       fname = "FILENAME_TO_IDS.csv",
                       null_cols=c(), 
                       not_null_cols=c(), 
                       nrows=-1)
{
    # FILENAME_TO_IDS.csv
    # FNAME
    # FID
    character_col_classes = c(
        "FNAME"
    )
    integer_col_classes = c(
        "FID"
    )
    #
    if (nchar(as.character(fname)) <= 0)
    {
        fname = "FILENAME_TO_IDS.csv"
    }
    path = paste(csv_path, fname, sep = "/")
    #
    headset = read.csv(path, header = TRUE, sep="\t", nrows = 10)
    classes = sapply(headset, class)
    #
    classes[names(classes) %in% character_col_classes] = "character"
    classes[names(classes) %in% integer_col_classes] = "integer"
    #
    all_classes = c(character_col_classes, 
                    integer_col_classes)
    classes[!(names(classes) %in% all_classes)] = "character"
    #
    if (length(null_cols) > 0)
    {
        classes[names(classes) %in% null_cols] = "NULL";
    }
    else if (length(not_null_cols) > 0)
    {
        classes[!(names(classes) %in% not_null_cols)] = "NULL";
    }
    #
    return(read.csv(path, header=TRUE, sep="\t", colClasses=classes, nrows=nrows))
}
#
read_HeightCorrect <- function(csv_path=".", 
                       fname = "HeightCorrect.csv",
                       null_cols=c(), 
                       not_null_cols=c(), 
                       nrows=-1)
{
    # HeightCorrect.csv
    # FID - integer
    # B - integer
    # IDNUM - integer
    # MeasureResult - numeric
    integer_col_classes = c(
        "FID",
        "B",
        "IDNUM"
    )
    numeric_col_classes = c(
        "MeasureResult"
    )
    #
    if (nchar(as.character(fname)) <= 0)
    {
        fname = "HeightCorrect.csv"
    }
    path = paste(csv_path, fname, sep = "/")
    #
    headset = read.csv(path, header = TRUE, sep="\t", nrows = 10)
    classes = sapply(headset, class)
    #
    classes[names(classes) %in% integer_col_classes] = "integer"
    classes[names(classes) %in% numeric_col_classes] = "numeric"
    #
    all_classes = c(integer_col_classes, 
                    numeric_col_classes)
    classes[!(names(classes) %in% all_classes)] = "character"
    #
    if (length(null_cols) > 0)
    {
        classes[names(classes) %in% null_cols] = "NULL";
    }
    else if (length(not_null_cols) > 0)
    {
        classes[!(names(classes) %in% not_null_cols)] = "NULL";
    }
    #
    return(read.csv(path, header=TRUE, sep="\t", colClasses=classes, nrows=nrows))
}
#
read_Index <- function(csv_path=".", 
                       fname = "Index.csv",
                       null_cols=c(), 
                       not_null_cols=c(), 
                       nrows=-1)
{
    # Index.csv
    # FID
    # NAME
    # VALUE
    character_col_classes = c(
        "NAME", 
        "VALUE"
    )
    integer_col_classes = c(
        "FID"
    )
    #
    if (nchar(as.character(fname)) <= 0)
    {
        fname = "Index.csv"
    }
    path = paste(csv_path, fname, sep = "/")
    #
    headset = read.csv(path, header = TRUE, sep="\t", nrows = 10)
    classes = sapply(headset, class)
    #
    classes[names(classes) %in% character_col_classes] = "character"
    classes[names(classes) %in% integer_col_classes] = "integer"
    #
    all_classes = c(character_col_classes, 
                    integer_col_classes)
    classes[!(names(classes) %in% all_classes)] = "character"
    #
    if (length(null_cols) > 0)
    {
        classes[names(classes) %in% null_cols] = "NULL";
    }
    else if (length(not_null_cols) > 0)
    {
        classes[!(names(classes) %in% not_null_cols)] = "NULL";
    }
    #
    return(read.csv(path, header=TRUE, sep="\t", colClasses=classes, nrows=nrows))
}
#
read_Information <- function(csv_path=".", 
                       fname = "Information.csv",
                       null_cols=c(), 
                       not_null_cols=c(), 
                       nrows=-1)
{
    # Information.csv
    # FID
    # NAME
    # VALUE
    character_col_classes = c(
        "NAME", 
        "VALUE"
    )
    integer_col_classes = c(
        "FID"
    )
    #
    if (nchar(as.character(fname)) <= 0)
    {
        fname = "Information.csv"
    }
    path = paste(csv_path, fname, sep = "/")
    #
    headset = read.csv(path, header = TRUE, sep="\t", nrows = 10)
    classes = sapply(headset, class)
    #
    classes[names(classes) %in% character_col_classes] = "character"
    classes[names(classes) %in% integer_col_classes] = "integer"
    #
    all_classes = c(character_col_classes, 
                    integer_col_classes)
    classes[!(names(classes) %in% all_classes)] = "character"
    #
    if (length(null_cols) > 0)
    {
        classes[names(classes) %in% null_cols] = "NULL";
    }
    else if (length(not_null_cols) > 0)
    {
        classes[!(names(classes) %in% not_null_cols)] = "NULL";
    }
    #
    return(read.csv(path, header=TRUE, sep="\t", colClasses=classes, nrows=nrows))
}
#
read_InspectionData <- function(csv_path=".", 
                       fname = "InspectionData.csv",
                       null_cols=c(), 
                       not_null_cols=c(), 
                       nrows=-1)
{
    # InspectionData.csv
    # FID
    # NAME
    # VALUE
    character_col_classes = c(
        "NAME", 
        "VALUE"
    )
    integer_col_classes = c(
        "FID"
    )
    #
    if (nchar(as.character(fname)) <= 0)
    {
        fname = "InspectionData.csv"
    }
    path = paste(csv_path, fname, sep = "/")
    #
    headset = read.csv(path, header = TRUE, sep="\t", nrows = 10)
    classes = sapply(headset, class)
    #
    classes[names(classes) %in% character_col_classes] = "character"
    classes[names(classes) %in% integer_col_classes] = "integer"
    #
    all_classes = c(character_col_classes, 
                    integer_col_classes)
    classes[!(names(classes) %in% all_classes)] = "character"
    #
    if (length(null_cols) > 0)
    {
        classes[names(classes) %in% null_cols] = "NULL";
    }
    else if (length(not_null_cols) > 0)
    {
        classes[!(names(classes) %in% not_null_cols)] = "NULL";
    }
    #
    return(read.csv(path, header=TRUE, sep="\t", colClasses=classes, nrows=nrows))
}
#
read_MountExchangeReel <- function(csv_path=".", 
                       fname = "MountExchangeReel.csv",
                       null_cols=c(), 
                       not_null_cols=c(), 
                       nrows=-1)
{
    # MountExchangeReel.csv
    # FID - integer
    # BLKCode - character
    # BLKSerial - character
    # Ftype - integer
    # FAdd - integer
    # FSAdd - integer
    # Use - integer
    # PEStatus - integer
    # PCStatus - integer
    # Remain - integer
    # Init - integer
    # PartsName - character
    # Custom1 - character
    # Custom2 - character
    # Custom3 - character
    # Custom4 - character
    # ReelID - character
    # PartsEmp - integer
    character_col_classes = c(
        "BLKCode",
        "BLKSerial",
        "PartsName",
        "Custom1",
        "Custom2",
        "Custom3",
        "Custom4",
        "ReelID"
    )
    integer_col_classes = c(
        "FID",
        "Ftype",
        "FAdd",
        "FSAdd",
        "Use",
        "PEStatus",
        "PCStatus",
        "Remain",
        "Init",
        "PartsEmp"
    )
    #
    if (nchar(as.character(fname)) <= 0)
    {
        fname = "MountExchangeReel.csv"
    }
    path = paste(csv_path, fname, sep = "/")
    #
    headset = read.csv(path, header = TRUE, sep="\t", nrows = 10)
    classes = sapply(headset, class)
    #
    classes[names(classes) %in% character_col_classes] = "character"
    classes[names(classes) %in% integer_col_classes] = "integer"
    #
    all_classes = c(character_col_classes, 
                    integer_col_classes)
    classes[!(names(classes) %in% all_classes)] = "character"
    #
    if (length(null_cols) > 0)
    {
        classes[names(classes) %in% null_cols] = "NULL";
    }
    else if (length(not_null_cols) > 0)
    {
        classes[!(names(classes) %in% not_null_cols)] = "NULL";
    }
    #
    return(read.csv(path, header=TRUE, sep="\t", colClasses=classes, nrows=nrows))
}
#
read_MountLatestReel <- function(csv_path=".", 
                       fname = "MountLatestReel.csv",
                       null_cols=c(), 
                       not_null_cols=c(), 
                       nrows=-1)
{
    # MountLatestReel.csv
    # FID - integer
    # BLKCode - character
    # BLKSerial - character
    # Ftype - integer
    # FAdd - integer
    # FSAdd - integer
    # Use - integer
    # PEStatus - integer
    # PCStatus - integer
    # Remain - integer
    # Init - integer
    # PartsName - character
    # Custom1 - character
    # Custom2 - character
    # Custom3 - character
    # Custom4 - character
    # ReelID - character
    # PartsEmp - integer
    character_col_classes = c(
        "BLKCode",
        "BLKSerial",
        "PartsName",
        "Custom1",
        "Custom2",
        "Custom3",
        "Custom4",
        "ReelID"
    )
    integer_col_classes = c(
        "FID",
        "Ftype",
        "FAdd",
        "FSAdd",
        "Use",
        "PEStatus",
        "PCStatus",
        "Remain",
        "Init",
        "PartsEmp"
    )
    #
    if (nchar(as.character(fname)) <= 0)
    {
        fname = "MountLatestTrace.csv"
    }
    path = paste(csv_path, fname, sep = "/")
    #
    headset = read.csv(path, header = TRUE, sep="\t", nrows = 10)
    classes = sapply(headset, class)
    #
    classes[names(classes) %in% character_col_classes] = "character"
    classes[names(classes) %in% integer_col_classes] = "integer"
    #
    all_classes = c(character_col_classes, 
                    integer_col_classes)
    classes[!(names(classes) %in% all_classes)] = "character"
    #
    if (length(null_cols) > 0)
    {
        classes[names(classes) %in% null_cols] = "NULL";
    }
    else if (length(not_null_cols) > 0)
    {
        classes[!(names(classes) %in% not_null_cols)] = "NULL";
    }
    #
    return(read.csv(path, header=TRUE, sep="\t", colClasses=classes, nrows=nrows))
}
#
read_MountNormalTrace <- function(csv_path=".", 
                       fname = "MountNormalTrace.csv",
                       null_cols=c(), 
                       not_null_cols=c(), 
                       nrows=-1)
{
    # MountNormalTrace.csv
    # FID - integer
    # B - integer
    # IDNUM - integer
    # FAdd - integer
    # FSAdd - integer
    # NHAdd - integer
    # NCAdd - integer
    # ReelID - character
    character_col_classes = c(
        "ReelID"
    )
    integer_col_classes = c(
        "FID", 
        "B", 
        "IDNUM", 
        "FAdd", 
        "FSAdd", 
        "NHAdd", 
        "NCAdd"
    )
    #
    if (nchar(as.character(fname)) <= 0)
    {
        fname = "MountNormalTrace.csv"
    }
    path = paste(csv_path, fname, sep = "/")
    #
    headset = read.csv(path, header = TRUE, sep="\t", nrows = 10)
    classes = sapply(headset, class)
    #
    classes[names(classes) %in% character_col_classes] = "character"
    classes[names(classes) %in% integer_col_classes] = "integer"
    #
    all_classes = c(character_col_classes, 
                    integer_col_classes)
    classes[!(names(classes) %in% all_classes)] = "character"
    #
    if (length(null_cols) > 0)
    {
        classes[names(classes) %in% null_cols] = "NULL";
    }
    else if (length(not_null_cols) > 0)
    {
        classes[!(names(classes) %in% not_null_cols)] = "NULL";
    }
    #
    return(read.csv(path, header=TRUE, sep="\t", colClasses=classes, nrows=nrows))
}
#
read_MountPickupFeeder <- function(csv_path=".", 
                       fname = "MountPickupFeeder.csv",
                       null_cols=c(), 
                       not_null_cols=c(), 
                       nrows=-1)
{
    # MountPickupFeeder.csv
    # FID - integer
    # BLKCode - character
    # BLKSerial - character
    # UseF - integer
    # PartsName - character
    # FAdd - integer
    # FSAdd - integer
    # ReelID - character
    # UseR - integer
    # Pickup - integer
    # PMiss - integer
    # RMiss - integer
    # DMiss - integer
    # MMiss - integer
    # HMiss - integer
    # TRSMiss - integer
    character_col_classes = c(
        "BLKCode",
        "BLKSerial",
        "PartsName",
        "ReelID"
    )
    integer_col_classes = c(
        "FID",
        "UseF",
        "FAdd",
        "FSAdd",
        "UseR",
        "Pickup",
        "PMiss",
        "RMiss",
        "DMiss",
        "MMiss",
        "HMiss",
        "TRSMiss"
    )
    #
    if (nchar(as.character(fname)) <= 0)
    {
        fname = "MountPickupFeeder.csv"
    }
    path = paste(csv_path, fname, sep = "/")
    #
    headset = read.csv(path, header = TRUE, sep="\t", nrows = 10)
    classes = sapply(headset, class)
    #
    classes[names(classes) %in% character_col_classes] = "character"
    classes[names(classes) %in% integer_col_classes] = "integer"
    #
    all_classes = c(character_col_classes, 
                    integer_col_classes)
    classes[!(names(classes) %in% all_classes)] = "character"
    #
    if (length(null_cols) > 0)
    {
        classes[names(classes) %in% null_cols] = "NULL";
    }
    else if (length(not_null_cols) > 0)
    {
        classes[!(names(classes) %in% not_null_cols)] = "NULL";
    }
    #
    return(read.csv(path, header=TRUE, sep="\t", colClasses=classes, nrows=nrows))
}
#
read_MountPickupNozzle <- function(csv_path=".", 
                       fname = "MountPickupNozzle.csv",
                       null_cols=c(), 
                       not_null_cols=c(), 
                       nrows=-1)
{
    # MountPickupNozzle.csv
    # FID - integer
    # Head - integer
    # NHAdd - integer
    # NCAdd - integer
    # BLKCode - character
    # BLKSerial - character
    # UseR - integer
    # NozzleName - integer
    # Pickup - integer
    # PMiss - integer
    # RMiss - integer
    # DMiss - integer
    # MMiss - integer
    # HMiss - integer
    # TRSMiss - integer
    character_col_classes = c(
        "BLKCode",
        "BLKSerial"
    )
    integer_col_classes = c(
        "FID",
        "Head",
        "NHAdd",
        "NCAdd",
        "UseR",
        "NozzleName",
        "Pickup",
        "PMiss",
        "RMiss",
        "DMiss",
        "MMiss",
        "HMiss",
        "TRSMiss"
    )
    #
    if (nchar(as.character(fname)) <= 0)
    {
        fname = "MountPickupNozzle.csv"
    }
    path = paste(csv_path, fname, sep = "/")
    #
    headset = read.csv(path, header = TRUE, sep="\t", nrows = 10)
    classes = sapply(headset, class)
    #
    classes[names(classes) %in% character_col_classes] = "character"
    classes[names(classes) %in% integer_col_classes] = "integer"
    #
    all_classes = c(character_col_classes, 
                    integer_col_classes)
    classes[!(names(classes) %in% all_classes)] = "character"
    #
    if (length(null_cols) > 0)
    {
        classes[names(classes) %in% null_cols] = "NULL";
    }
    else if (length(not_null_cols) > 0)
    {
        classes[!(names(classes) %in% not_null_cols)] = "NULL";
    }
    #
    return(read.csv(path, header=TRUE, sep="\t", colClasses=classes, nrows=nrows))
}
#
read_Time <- function(csv_path=".", 
                       fname = "Time.csv",
                       null_cols=c(), 
                       not_null_cols=c(), 
                       nrows=-1)
{
    # Time.csv
    # FID
    # NAME
    # VALUE
    character_col_classes = c(
        "NAME", 
        "VALUE"
    )
    integer_col_classes = c(
        "FID"
    )
    #
    if (nchar(as.character(fname)) <= 0)
    {
        fname = "Time.csv"
    }
    path = paste(csv_path, fname, sep = "/")
    #
    headset = read.csv(path, header = TRUE, sep="\t", nrows = 10)
    classes = sapply(headset, class)
    #
    classes[names(classes) %in% character_col_classes] = "character"
    classes[names(classes) %in% integer_col_classes] = "integer"
    #
    all_classes = c(character_col_classes, 
                    integer_col_classes)
    classes[!(names(classes) %in% all_classes)] = "character"
    #
    if (length(null_cols) > 0)
    {
        classes[names(classes) %in% null_cols] = "NULL";
    }
    else if (length(not_null_cols) > 0)
    {
        classes[!(names(classes) %in% not_null_cols)] = "NULL";
    }
    #
    return(read.csv(path, header=TRUE, sep="\t", colClasses=classes, nrows=nrows))
}
