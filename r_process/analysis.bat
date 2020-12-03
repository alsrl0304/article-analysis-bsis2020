IF NOT EXIST %3 ( mkdir %3 )

Rscript --encoding=utf8 1_extract_nouns.r -i %1 -f %2 -o %3\nouns.csv

Rscript --encoding=utf8 2_frequency.r -i %3\nouns.csv -n 25 -o %3\frequent.csv

Rscript --encoding=utf8 3_topic_coherence.r -i %3\nouns.csv -m 5 -M 15 -o %3\coherence.csv

Rscript --encoding=utf8 4_gibbs_sampling.r -i %3\nouns.csv -n 25 -T %3\coherence.csv -o %3\gibbs.RData

Rscript --encoding=utf8 5_topwords_topics.r -i %3\gibbs.RData -o %3\topwords.csv

Rscript --encoding-utf8 6_proportion_topics.r -i %3\gibbs.RData -o %3\proportion.csv

Rscript --encoding-utf8 7_trend_topics.r -i %3\gibbs.RData -p 2 -o %3\trend.csv

Rscript --encoding-utf8 8_wordcloud.r -i %3\frequent.csv -o %3\wordcloud

Rscript --encoding-utf8 9_idm_visualization.r -i %3\gibbs.RData -o %3\IDM\
powershell -command "Get-Content %3\IDM\lda.json | Set-Content -Encoding utf8 %3\IDM\lda2.json"
del %3\IDM\lda.json
move %3\IDM\lda2.json %3\IDM\lda.json
