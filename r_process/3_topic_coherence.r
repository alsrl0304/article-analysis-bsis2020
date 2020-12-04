##############################################################
# 최적 Topic 수 결정을 위한 Topic coherence 계산               #
##############################################################

####################### 명령행 인수 처리 #######################
library(getopt)
library(tools)

argSpec <- matrix(c(
    'help', 'h', 0, 'logical', "도움말",
    'input', 'i', 1, 'character', "명사 추출한 기사 csv 파일",
    'minimum-topics', 'm', 1, 'integer', "Coherence 시험할 최소 토픽 수(기본값 2)",
    'maximum-topics', 'M', 1, 'integer', "Coherence 시험할 최대 토픽 수(기본값 15)",
    'output', 'o', 1, 'character', "Coherence 결과 저장할 csv 파일 (Default coherence_{input}.csv)"
), byrow=TRUE, ncol=5)

opts <- getopt(argSpec)

if (!is.null(opts$help)) {
    cat(getopt(argSpec, usage=TRUE))
    q(status=1)
}

nounsFileName <- opts$input
minTopics <- opts$`minimum-topics`
maxTopics <- opts$`maximum-topics`
coherenceFileName <- opts$output

if (is.null(nounsFileName)) {
    cat(getopt(argSpec, usage=TRUE))
    q(status=1)
}

if (is.null(minTopics)) {
    minTopics <- 2
}

if (is.null(maxTopics)) {
    maxTopics <- 15
}

if (is.null(coherenceFileName)) {
    coherenceFileName <- paste(paste("coherence", 
        file_path_sans_ext(basename(nounsFileName)), sep="_"), ".csv", sep='')
}

#################### Topic Coherence 계산 ####################
library(textmineR)

# $date (작성일), $title (제목), $body (기사 본문)
articlesDataFrame <- read.csv(nounsFileName, header = TRUE, fileEncoding = "UTF-8", stringsAsFactors=FALSE)

cat("\nDocument Term Matrix 생성... ")
set.seed(1502)
dtmArticles = CreateDtm(doc_vec = articlesDataFrame$body,
                    doc_names = 1:length(articlesDataFrame$body),
                    ngram_window = c(1,2),
                    stopword_vec = c(),
                    verbose = FALSE)

dtmArticles <- dtmArticles[,colSums(dtmArticles)>2]

cat("[완료]")

cat("\nLDA 모델 훈련 시작... \n")
set.seed(1502)

coherenceDataFrame <- data.frame(topics = minTopics:maxTopics)
coherenceMeanColumn <- c()

# Topic 수를 늘려가면서 LDA 모델 훈련
for (numOfTopic in minTopics:maxTopics) {
    articlesLdaModel <- FitLdaModel(dtm = dtmArticles, k = numOfTopic,
                            iterations = 500, burnin = 180,
                            alpha = 0.1,beta = 0.05,
                            optimize_alpha = TRUE,
                            calc_likelihood = TRUE,
                            calc_coherence = TRUE,
                            calc_r2 = TRUE)
    
    cat("> 훈련 완료 (Topic 수: ", numOfTopic, ")\n", sep='')
    coherenceMeanColumn <- append(coherenceMeanColumn, mean(articlesLdaModel$coherence))
}
coherenceDataFrame$coherence <- coherenceMeanColumn
cat("\n[완료]")

write.table(coherenceDataFrame, coherenceFileName, sep=", ", row.names = FALSE, fileEncoding="UTF-8")
cat("\n")
