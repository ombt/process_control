#
# general purpose utils
#
closedevs <- function()
{
    while (dev.cur() > 1) { dev.off() }
}

closealldevs <- function()
{
    closedevs()
}

mysrc <- function(file)
{
    closealldevs()
    source(file=file, echo=TRUE, max.deparse.length=10000)
}

lnrow <- function(dfrm) 
{
    lapply(dfrm, nrow)
}

lncol <- function(dfrm) 
{
    lapply(dfrm, ncol)
}

lclass <- function(dfrm) 
{
    lapply(dfrm, class)
}

lhead <- function(dfrm) 
{
    lapply(dfrm, head)
}

lnames <- function(dfrm) 
{
    lapply(dfrm, names)
}
#
# estimate for e using monte-carlo. just choose a value for N.
#
# from R-bloggers
#
mc_e <- function(N=100000)
{
    1/mean(N*diff(sort(runif(N+1))) > 1)
}

