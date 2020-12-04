@echo off

rem %1(1번째 인자): 스크랩 파일 이름
rem %2(2번째 인자): 불용어 파일 이름
rem %3(3번째 인자): 작업 결과 저장할 디렉토리명

rem 작업 결과 저장할 디렉토리, 없으면 생성함
IF NOT EXIST %3 ( mkdir %3 )

rem 명사 추출
Rscript --encoding=utf8 1_extract_nouns.r -i %1 -f %2 -o %3\nouns.csv
IF NOT EXIST %3\nouns.csv ( EXIT /B )

rem 최고 빈도수 단어 확인
Rscript --encoding=utf8 2_frequency.r -i %3\nouns.csv -n 25 -o %3\frequent.csv
IF NOT EXIST %3\frequent.csv ( EXIT /B )

rem Topic Coherence 계산
Rscript --encoding=utf8 3_topic_coherence.r -i %3\nouns.csv -m 5 -M 15 -o %3\coherence.csv
IF NOT EXIST %3\coherence.csv ( EXIT /B )

rem Gibbs Sampling 수행
Rscript --encoding=utf8 4_gibbs_sampling.r -i %3\nouns.csv -n 25 -T %3\coherence.csv -o %3\gibbs.RData
IF NOT EXIST %3\gibbs.RData ( EXIT /B )

rem Topic 별 상위 단어 확인
Rscript --encoding=utf8 5_topwords_topics.r -i %3\gibbs.RData -o %3\topwords.csv
IF NOT EXIST %3\topwords.csv ( EXIT /B )

rem 각 Topic 비중 확인
Rscript --encoding-utf8 6_proportion_topics.r -i %3\gibbs.RData -o %3\proportion.csv
IF NOT EXIST %3\proportion.csv ( EXIT /B )

rem Topic 비중의 변화 확인
Rscript --encoding-utf8 7_trend_topics.r -i %3\gibbs.RData -p 2 -o %3\trend.csv
IF NOT EXIST %3\trend.csv ( EXIT /B )

rem 워드클라우드 생성
Rscript --encoding-utf8 8_wordcloud.r -i %3\frequent.csv -o %3\wordcloud
IF NOT EXIST %3\wordcloud ( EXIT /B )

rem IDM 시각화
Rscript --encoding-utf8 9_idm_visualization.r -i %3\gibbs.RData -o %3\IDM\
IF NOT EXIST %3\IDM\ ( EXIT /B )

rem 인코딩 변경 (UTF8-BOM)
powershell -command "Get-Content %3\IDM\lda.json | Set-Content -Encoding UTF8 %3\IDM\lda2.json"
del %3\IDM\lda.json > nul
move %3\IDM\lda2.json %3\IDM\lda.json > nul

