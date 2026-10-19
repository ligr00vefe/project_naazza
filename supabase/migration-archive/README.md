기존 로컬 파일과 실제 서버 적용 버전의 타임스탬프가 달랐다. 서버 history에서 migration fetch로 가져온 파일을 현재 migrations의 기준으로 사용한다. 여기의 과거 사본은 보존용이며 다시 적용하지 않는다. 서버 이력을 reverted로 바꾸거나 과거 SQL을 중복 적용하지 않았다.
