##############################################################
# Gibbs sampling 된 Topic 당 최고 빈도수 단어 추출             #
##############################################################

####################### 명령행 인수 처리 ######################
library(getopt)
library(tools)

argSpec <- matrix(c(
    'help', 'h', 0, 'logical', "도움말",
    'input', 'i', 1, 'character', "Gibbs Sampling 모델 RData 파일",
    'output', 'o', 1, 'character', "각 Topic 당 상위 단어 csv 파일 (기본값 topwords_{input}.csv)",
    'rates', 'r', 2, 'character', "(선택) 상위 단어의 Topic별 비율 csv 파일 (기본값 wordsrate_{input}.csv)"
), byrow=TRUE, ncol=5)

opts <- getopt(argSpec)

if (!is.null(opts$help)) {
    cat(getopt(argSpec, usage=TRUE))
    q(status=1)
}

modelFileName <- opts$input
topWordsFileName <- opts$output

shouldMakeRates <- TRUE
wordsRateFileName <- opts$rates

if (is.null(modelFileName)) {
    cat(getopt(argSpec, usage=TRUE))
    q(status=1)
}

if (is.null(topWordsFileName)) {
    topWordsFileName <- paste(paste("topwords",
        file_path_sans_ext(basename(modelFileName)), sep="_"), ".csv", sep='')
}

if (is.null(wordsRateFileName)) {
    shouldMakeRates <- FALSE
} else if (wordsRateFileName == "TRUE") {
    wordsRateFileName <- paste(paste("wordsrate",
        file_path_sans_ext(basename(modelFileName)), sep="_"), ".csv", sep='')
}

############## 각 Topic 당빈도수 상위 단어 추출 ###############
library(rJava)
library(stringr)
library(SnowballC)
library(servr)
library(tm)
library(topicmodels)
library(lda)

load(modelFileName)

cat("\nTopic 당 상위 단어 확인... ")
# topic에 대해 빈도가 높은 상위 단어 나열
topTopicWordsMatrix <- top.topic.words(gibbsResult$topics, wordsNum, by.score = TRUE) 

cat("[완료]")
# topic 별로 빈도가 높은 상위 단어들을 파일로 저장 (전치시킴)
write.table(t(topTopicWordsMatrix), topWordsFileName, sep=",", row.names = TRUE, fileEncoding="UTF-8")

############### 각 Topic 별 상위 단어 비율 계산 ###############

if (shouldMakeRates) {
    cat("\n각 Topic 별 상위 단어 비율 계산... ")
    # topic에 나온 단어들(topic별 상위 단어)을 matrix에서 vector로 변환
    topTopicWordsVector <- as.character(topTopicWordsMatrix)

    # topic 결과에서 각 topic별 상위 단어들의 집합에 대한 부분을 추출
    # toptopics는 각 topic별로 상위 단어들만 갖고 있다면, 
    # 이 변수는 각 topic별로 모든 topic의 상위 단어들 집합에 대한 출현수를 갖고 있음
    wordsFrequencyMatrix <- subset(gibbsResult$topics, select=topTopicWordsVector)

    # 각 topic에 대해 word들의 빈도수를 해당 topic의 총 word 수로 나눠줌
    wordsRatesMatrix <- wordsFrequencyMatrix / gibbsResult$topic_sums[,1]

    # 비율값을 소수점이하 3째 자리로 반올림
    wordsRatesMatrix <- round(wordsRatesMatrix, digits = 3) 

    cat("[완료]")

    # topic별 상위 단어들과 그 비율을 2차원 행렬 형태의 파일로 저장
    write.table(wordsRatesMatrix, wordsRateFileName, sep=",", row.names = TRUE, col.names = NA, fileEncoding="UTF-8")
}

cat("\n")
