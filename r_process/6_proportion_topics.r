##############################################################
# Gibbs sampling된 Topic 별 문서 비중 계산                     #
##############################################################

####################### 명령행 인수 처리 ######################
library(getopt)
library(tools)

argSpec <- matrix(c(
    'help', 'h', 0, 'logical', "도움말",
    'input', 'i', 1, 'character', "Gibbs Sampling 모델 RData 파일",
    'output', 'p', 1, 'character', "각 Topic 당 기사 비중 csv 파일 (기본값 proportion_{input}.csv)"
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

cat("\n각 Topic 당 비중 계산... ")
# 각 topic의 비중을 계산
topicPropotion <- gibbsResult$topic_sums[,1]/sum(gibbsResult$topic_sums[,1]) 

cat("[완료]")

# 전기간 topic 별 비중을 파일로 저장
write.table(topicPropotion, proportionFileName, sep=",", row.names = TRUE, col.names = NA, fileEncoding="UTF-8")
cat("\n\n작업 완료.\n")