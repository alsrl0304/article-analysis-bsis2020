##############################################################
# Gibbs sampling된 Topic 별 문서 비중 계산                     #
##############################################################

####################### 명령행 인수 처리 ######################
library(getopt)
library(tools)

argSpec <- matrix(c(
    'help', 'h', 0, 'logical', "help",
    'input', 'i', 1, 'character', "Trained Gibbs Sampling Model, RData File",
    'output', 'o', 1, 'character', "Articles Proportion of each Topics (기본값 proportion_{input}.csv)"
), byrow=TRUE, ncol=5)

opts <- getopt(argSpec)

if (!is.null(opts$help)) {
    cat(getopt(argSpec, usage=TRUE))
    q(status=1)
}

modelFileName <- opts$input
proportionFileName <- opts$output

if (is.null(modelFileName)) {
    cat(getopt(argSpec, usage=TRUE))
    q(status=1)
}

if (is.null(proportionFileName)) {
    proportionFileName <- paste(paste("proportion",
        file_path_sans_ext(basename(modelFileName)), sep="_"), ".csv", sep='')
}

#################### 각 Topic의 비중 계산 ####################
library(rJava)
library(stringr)
library(SnowballC)
library(servr)
library(tm)
library(topicmodels)
library(lda)

load(modelFileName)

cat("Calculating Articles Proportion of each Topics... ")
# 각 topic의 비중을 계산
topicPropotion <- gibbsResult$topic_sums[,1]/sum(gibbsResult$topic_sums[,1]) 

cat("[DONE]\n")

# 전기간 topic 별 비중을 파일로 저장
write.table(topicPropotion, proportionFileName, sep=",", row.names = TRUE, col.names = NA, fileEncoding="UTF-8")