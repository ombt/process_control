#
# open connection to sqlite database
#
sqlite_open_db <- function(db_path=".", db_name=":memory:")
{
    #
    # check if a package is installed. if not, then install
    # and download.
    #
    lapply_install_and_load <- function (package1, ...)
    {
        verbose = FALSE
        #
        # convert arguments to vector
        #
        packages <- c(package1, ...)
        #
        # check if loaded and installed
        #
        loaded        <- packages %in% (.packages())
        names(loaded) <- packages
        #
        installed        <- packages %in% rownames(installed.packages())
        names(installed) <- packages
        #
        # start loop to determine if each package is installed
        #
        load_it <- function (package, loaded, installed)
        {
            if (loaded[package])
            {
                if (verbose) print(paste(package, "is loaded"))
            }
            else
            {
                if (verbose) print(paste(package, "is not loaded"))
                if (installed[package])
                {
                    if (verbose) print(paste(package, "is installed"))
                    if (verbose) print(paste("loading", package))
                    do.call("library", list(package))
                }
                else
                {
                    if (verbose) print(paste(package, "is not installed"))
                    if (verbose) print(paste("installing", package))
                    install.packages(package)
                    if (verbose) print(paste("loading", package))
                    do.call("library", list(package))
                }
            }
        }
        #
        lapply(packages, load_it, loaded, installed)
    }
    #
    status = lapply_install_and_load("RSQLite")
    if (identical(db_name, ":memory:"))
    {
        full_db_path = db_name
    }
    else
    {
        full_db_path = paste(db_path, db_name, sep = "/")
    }
    db=dbConnect(dbDriver("SQLite"), full_db_path)
    return(list("db"=db, "tbls"=dbListTables(db)))
}
#
# close connection
#
sqlite_close_db <- function(db)
{
    status = dbDisconnect(db$db)
}
#
# read in a table
#
sqlite_load_table_from_db <- function(db,table_name,nrows=0)
{
    if (table_name %in% db$tbls)
    {
        if (nrows > 0)
        {
            # quote the table name since Index is a key-word in SQL
            query=paste("select * from '", table_name, "' limit ", nrows, sep="")
        }
        else
        {
            # quote the table name since Index is a key-word in SQL
            query=paste("select * from '", table_name, "'", sep="")
        }
        results = dbGetQuery(db$db, query)
        return(results)
    }
    else
    {
        return(data.frame())
    }
}
#
# execute a query
#
sqlite_exec_query_db <- function(db, query)
{
    return(dbGetQuery(db$db, query))
}
#
# used to convert name-value tables to lists. examples
# of these tables are: count, cycletime, index, information,
# inspectiondata and time.
#
sqlite_load_nv_table_from_db <- function(db, table_name, nrows=0)
{
    if (nrows > 0)
        query = paste("select * from '", table_name,"' ", "limit ", nrows, sep="")
    else
        query = paste("select * from '", table_name,"'", sep="")
    #
    # get data for table.
    #
    nv_tbl = sqlite_exec_query_db(db, query)
    #
    # get column names
    #
    field_names = levels(as.factor(nv_tbl$NAME))
    #
    # get the number of FIDs.
    #
    nv_tbl$FID = as.integer(nv_tbl$FID)
    sorted_unique_fids = sort(unique(nv_tbl$FID))
    nfids = length(sorted_unique_fids)
    #
    # initialize the new data frame.
    #
    new_tbl = data.frame(FID=sorted_unique_fids)
    for (fld in field_names)
    {
        # new_tbl[[fld]] = rep(c(""), times=1, len=nfids)
        new_tbl[[fld]] = character(nfids)
    }
    #
    for (irec in 1:nrow(nv_tbl))
    {
        FID   = nv_tbl[irec,"FID"] # already integer. see above.
        NAME  = nv_tbl[irec,"NAME"]
        VALUE = nv_tbl[irec,"VALUE"]
        #
        # OLD = new_tbl[FID,NAME] = VALUE
        new_tbl[new_tbl$FID==FID,NAME] = VALUE
    }
    #
    new_tbl
}
#
sqlite_load_nv_table_from_db_old <- function(db, table_name, nrows=0)
{
    if (nrows > 0)
        query = paste("select * from '", table_name,"' ", "limit ", nrows, sep="")
    else
        query = paste("select * from '", table_name,"'", sep="")
    #
    nv_tbl = sqlite_exec_query_db(db, query)
    #
    nv_tbl$NAME = as.factor(nv_tbl$NAME)
    field_names = c("FID", levels(nv_tbl$NAME))
    tuple = rep(NA, length(field_names))
    names(tuple) = field_names
    #
    nv_tbl$FID = as.integer(nv_tbl$FID)
    sorted_unique_fids = sort(unique(nv_tbl$FID))
    #
    count_nrows = length(sorted_unique_fids)
    #
    by_fid <- function(fid, field_names, nv_tbl)
    {
        tuple = rep(NA, times = length(field_names))
        names(tuple) = field_names
        #
        cval = as.vector(nv_tbl[nv_tbl$FID==fid,"VALUE"])
        cnm = as.vector(nv_tbl[nv_tbl$FID==fid,"NAME"])
        names(cval) = cnm
        #
        tuple[cnm] = cval[cnm]
        tuple["FID"] = fid
        #
        # print(paste("FID=",fid,sep=""))
        #
        tuple
    }
    #
    lapply(sorted_unique_fids, by_fid, field_names, nv_tbl)
}
#
