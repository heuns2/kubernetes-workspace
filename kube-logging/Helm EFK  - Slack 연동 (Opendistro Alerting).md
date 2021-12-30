# Helm EFK  - Slack 연동 (Opendistro Alerting)
- 본 문서는 Helm v3으로 설치한 Elastics Search를 통하여 특정 Log가 검출 되면 Slack Webhook Endpoint를 통하여 Alert가 발생 하도록 통합 연동을 위한 문서입니다.
- 예시는 특정 Log에서 ERROR라는 문구가 발생하면 Slack으로 Alert를 발생 시키는 예제 입니다.
- Kibana에서 Alert를 구성 할 수 있도록 생성 합니다.
- 방법은 Helm Chart의 Init Container를 통하여 Opendistro Alerting Plugin을 설치하여 Kibana, Elastics Search Pod 내부 Plugin Directory를 Shared하거나 Dockerfile 생성이 있습니다. 본 문서는 Docker Image를 Custom 생성하여 배포 하는 방안입니다.
- Elastic Search, Kibana v7.10.2, Fleuntd가 설치되어 있는 환경에서 진행
- 참고 링크
	- [opendistro](https://opendistro.github.io/for-elasticsearch/)

## 1. Docker File 생성


### 1.1. Elastics Search Docker File 생성
- Elastics 용 Opendistro Plugin이 Packaging 되어 있는 Docker Image 생성합니다.

```
ARG elasticsearch_version
FROM docker.elastic.co/elasticsearch/elasticsearch:7.10.2

RUN bin/elasticsearch-plugin install --batch https://d3g5vo6xdbdb9a.cloudfront.net/downloads/elasticsearch-plugins/opendistro-alerting/opendistro-alerting-1.13.1.0.zip
```

```
# Image Build
$ docker build -t leedh/elastic-search:7.10.2 .

# Image Push (Docker Hub가 아닐 경우 Tag를 별도로 지정하고 Private Repo에 로그인하여 진행)
$ docker login
$ docker push leedh/elastic-search:7.10.2
```

### 1.2. Kibana Docker File 생성
- Kibana 용 Opendistro Plugin이 Packaging 되어 있는 Docker Image 생성합니다.

```
ARG kibana_version
FROM docker.elastic.co/kibana/kibana:7.10.2

RUN bin/kibana-plugin install https://d3g5vo6xdbdb9a.cloudfront.net/downloads/kibana-plugins/opendistro-alerting/opendistroAlertingKibana-1.13.0.0.zip
```

```
# Image Build
$ docker build -t leedh/kibana:7.10.2 .

# Image Push (Docker Hub가 아닐 경우 Tag를 별도로 지정하고 Private Repo에 로그인하여 진행)
$ docker login
$ docker push leedh/kibana:7.10.2
```


## 2. Elastic과 Kibana 설정 변경

- Elastic과 Kibana v7.10.2 버전을 Pull 하여 values.yaml의 Elastic Search, Kibana Image를 변경하거나 --set 을 통하여 바로 설치

### 2.1. Elastics Search Helm 설정 변경
- Local에 Elastic Search Helm Chart를 Download하여 설정을 변경하고 배포 합니다.

```
$ helm pull elastic/elasticsearch --version 7.10.2 --untar

# elasticsearch 디렉토리로 이동하여 values.yaml 중 아래 설정을 변경
image: "leedh/elastic-search"
imageTag: "7.10.2"

# helm upgrade를 통하여 이미지 변경
$ helm upgrade --install --name elasticsearch elastic/elasticsearch --version 7.10.2
```

### 2.2. Kibana Helm 설정 변경


```
$ helm pull elastic/kibana --version 7.10.2 --untar

# Kibana 디렉토리로 이동하여 values.yaml 중 아래 설정을 변경
image: "leedh/kibana"
imageTag: "7.10.2"

# helm upgrade를 통하여 이미지 변경
$ helm upgrade --install kibana . --namespace eks-monitoring
```

## 3. Kibana UI 확인

- Kibana UI Menu에서  Open Distro for Elasticsearch가 생성 되었는지 확인합니다.

![distro-slack-1][distro-slack-1]

[distro-slack-1]:./images/distro-slack-1.PNG


## 4. Kibana UI에서 Distro Alert 설정

### 4.1. Open Distro - Slack 연동

- Kibana UI Menu에서  Open Distro for Elasticsearch 메뉴로 이동하여 [Destinations]의 [Add  destination]버튼을 클릭하여 Slack 정보 입력합니다.


![distro-slack-2][distro-slack-2]

[distro-slack-2]:./images/distro-slack-2.PNG

- [Monitors] 메뉴의 [Create monitor] 버튼을 클릭하여 Monitors 정보를 입력합니다.
- Query의 Sample은 아래와 같습니다. (range의 Timestamp 확인)

```
{
    "size": 500,
    "query": {
        "bool": {
            "filter": [
                {
                    "multi_match": {
                        "query": "ERROR",
                        "fields": [],
                        "type": "best_fields",
                        "operator": "OR",
                        "slop": 0,
                        "prefix_length": 0,
                        "max_expansions": 50,
                        "lenient": true,
                        "zero_terms_query": "NONE",
                        "auto_generate_synonyms_phrase_query": true,
                        "fuzzy_transpositions": true,
                        "boost": 1
                    }
                },
                {
                    "match_phrase": {
                        "message": {
                            "query": "ERROR",
                            "slop": 0,
                            "zero_terms_query": "NONE",
                            "boost": 1
                        }
                    }
                },
                {
                    "range": {
                        "@timestamp": {
                            "from": "{{period_end}}||-15s",
                            "to": "{{period_end}}",
                            "include_lower": true,
                            "include_upper": true,
                            "format": "epoch_millis",
                            "boost": 1
                        }
                    }
                }
            ],
            "adjust_pure_negative": true,
            "boost": 1
        }
    },
    "version": true,
    "_source": {
        "includes": [],
        "excludes": []
    },
    "stored_fields": "*",
    "docvalue_fields": [
        {
            "field": "@timestamp",
            "format": "date_time"
        },
        {
            "field": "grpc.start_time",
            "format": "date_time"
        },
        {
            "field": "scheduled",
            "format": "date_time"
        },
        {
            "field": "timestamp",
            "format": "date_time"
        },
        {
            "field": "ts",
            "format": "date_time"
        }
    ],
    "script_fields": {},
    "sort": [
        {
            "@timestamp": {
                "order": "desc",
                "unmapped_type": "boolean"
            }
        }
    ],
    "aggregations": {
        "2": {
            "date_histogram": {
                "field": "@timestamp",
                "time_zone": "Asia/Seoul",
                "fixed_interval": "200ms",
                "offset": 0,
                "order": {
                    "_key": "asc"
                },
                "keyed": false,
                "min_doc_count": 1
            }
        }
    },
    "highlight": {
        "pre_tags": [
            "@kibana-highlighted-field@"
        ],
        "post_tags": [
            "@/kibana-highlighted-field@"
        ],
        "fragment_size": 2147483647,
        "fields": {
            "*": {}
        }
    }
}
```

![distro-slack-3][distro-slack-3]

[distro-slack-3]:./images/distro-slack-3.PNG


- Create  trigger 정보를 입력 합니다. 주요 정보는 아래 Slack으로 연동 시 어떠한 데이터를 어떠한 임계치에서 Alert로 보내는지에 대한 설정입니다.
- Default는 'ctx.results[0].hits.total.value > 0' 의 경우 Alert가 발생합니다. Query에 대한 결과는 ctx에 Object Array로 들어가며 적중 Count가 0보다 클 경우 Slack으로 Alert를 보내는 Action을 실행 합니다.


![distro-slack-4][distro-slack-4]

[distro-slack-4]:./images/distro-slack-4.PNG

- Message 예시 처럼 For문을 실행 시킬 수 있고, If 문도 실행 시킬 수 있는 것으로 파악 됩니다.

```
> Find Pods Error Logs

:worried::worried::worried::worried::worried::worried::worried:

{{#ctx.results.0.hits.hits}}
`{{_source.kubernetes.container_name}} Error!!  {{_source.@timestamp}} {{_source.message}}`
{{/ctx.results.0.hits.hits}}
```


## 5. Slack 화면 확인

- Slack으로 Alert가 전송 되는지 확인 합니다.

![distro-slack-5][distro-slack-5]

[distro-slack-5]:./images/distro-slack-5.PNG


