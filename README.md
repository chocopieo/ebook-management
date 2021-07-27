![image](https://user-images.githubusercontent.com/31404198/126869803-2cddade9-2542-47fa-bba2-6738f1529220.png)

# 전자도서관리시스템

- Repository
  - 도서관리 : https://github.com/chocopieo/ebookmgmt-book.git
  - 예약관리 : https://github.com/chocopieo/ebookmgmt-rent.git
  - 결제관리 : https://github.com/chocopieo/ebookmgmt-payment.git
  - 마이페이지 : https://github.com/chocopieo/ebookmgmt-dashboard.git
  - API 게이트웨이 : https://github.com/chocopieo/ebookmgmt-gateway.git
- 체크포인트 : https://workflowy.com/s/assessment-check-po/T5YrzcMewfo4J6LW

# Table of contents
- [전자도서관리시스템](#---)  
  - [서비스 시나리오](#서비스-시나리오)    
  - [체크포인트](#체크포인트)    
  - [분석/설계](#분석설계)    
  - [구현](#구현)
    - [게이트웨이 적용](#게이트웨이-적용)
    - [DDD 의 적용](#ddd-의-적용)
    - [폴리글랏 퍼시스턴스](#폴리글랏-퍼시스턴스)
    - [동기식 호출 과 Fallback 처리](#동기식-호출-과-fallback-처리)
    - [비동기식 호출 과 Eventual Consistency](#비동기식-호출--시간적-디커플링--장애격리--최종-eventual-일관성-테스트)
    - [Correlation-key](#correlation-key)
    - [CQRS](#cqrs)
  - [운영](#운영)
    - [Deploy / Pipeline](#deploy--pipeline)
    - [동기식 호출 / 서킷 브레이킹 / 장애격리](#동기식-호출--서킷-브레이킹--장애격리)
    - [오토스케일 아웃](#오토스케일-아웃)
    - [무정지 재배포(Readiness Probe)](#무정지-재배포readiness-probe)
    - [Config Map](#config-map)
    - [Self-healing(Liveness Probe)](#self-healing-liveness-probe)


# 서비스 시나리오

기능적 요구사항
1. 관리자가 전자책을 등록한다.
2. 회원이 전자책을 선택하여 대여 신청한다.
3. 회원이 결제한다.
4. 대여신청이 되면 신청내역이 관리자에게 전달된다.
5. 관리자는 신청내역을 확인하고 대여승인 또는 대여거절 한다.
6. 대여승인이 되면 회원은 대여가 시작된다.
7. 회원이 전자책을 반납한다.
8. 대여거절이 되면 결제가 취소된다.
9. 결제가 취소되면 대여가 취소된다.
10. 회원이 대여현황을 중간중간 조회한다.

비기능적 요구사항
1. 트랜잭션
    1. 결제가 되지 않은 예약 건은 아예 승인이 성립되지 않아야 한다 -> Sync 호출
2. 장애격리
    1. 관리자 기능이 수행되지 않더라도 예약는 365일 24시간 가능해야 한다 -> Async (event-driven), Eventual Consistency
    2. 결제시스템이 과중되면 사용자를 잠시동안 받지 않고 결제를 잠시후에 하도록 유도한다 -> Circuit breaker, fallback
3. 성능
    1. 회원이 대여상태를 자주 대여관리 시스템(프론트엔드)에서 확인할 수 있어야 한다 -> CQRS


# 체크포인트

- 분석 설계

  - 이벤트스토밍
    - 스티커 색상별 객체의 의미를 제대로 이해하여 헥사고날 아키텍처와의 연계 설계에 적절히 반영하고 있는가?
    - 각 도메인 이벤트가 의미있는 수준으로 정의되었는가?
    - 어그리게잇: Command와 Event 들을 ACID 트랜잭션 단위의 Aggregate 로 제대로 묶었는가?
    - 기능적 요구사항과 비기능적 요구사항을 누락 없이 반영하였는가?    
  - 서브 도메인, 바운디드 컨텍스트 분리
    - 팀별 KPI 와 관심사, 상이한 배포주기 등에 따른  Sub-domain 이나 Bounded Context 를 적절히 분리하였고 그 분리 기준의 합리성이 충분히 설명되는가?
      - 적어도 3개 이상 서비스 분리
    - 폴리글랏 설계: 각 마이크로 서비스들의 구현 목표와 기능 특성에 따른 각자의 기술 Stack 과 저장소 구조를 다양하게 채택하여 설계하였는가?
    - 서비스 시나리오 중 ACID 트랜잭션이 크리티컬한 Use 케이스에 대하여 무리하게 서비스가 과다하게 조밀히 분리되지 않았는가?
  - 컨텍스트 매핑 / 이벤트 드리븐 아키텍처 
    - 업무 중요성과  도메인간 서열을 구분할 수 있는가? (Core, Supporting, General Domain)
    - Request-Response 방식과 이벤트 드리븐 방식을 구분하여 설계할 수 있는가?
    - 장애격리: 서포팅 서비스를 제거 하여도 기존 서비스에 영향이 없도록 설계하였는가?
    - 신규 서비스를 추가 하였을때 기존 서비스의 데이터베이스에 영향이 없도록 설계(열려있는 아키택처)할 수 있는가?
    - 이벤트와 폴리시를 연결하기 위한 Correlation-key 연결을 제대로 설계하였는가?
  - 헥사고날 아키텍처
    - 설계 결과에 따른 헥사고날 아키텍처 다이어그램을 제대로 그렸는가?
    
- 구현

  - [DDD] 분석단계에서의 스티커별 색상과 헥사고날 아키텍처에 따라 구현체가 매핑되게 개발되었는가?
    - Entity Pattern 과 Repository Pattern 을 적용하여 JPA 를 통하여 데이터 접근 어댑터를 개발하였는가
    - [헥사고날 아키텍처] REST Inbound adaptor 이외에 gRPC 등의 Inbound Adaptor 를 추가함에 있어서 도메인 모델의 손상을 주지 않고 새로운 프로토콜에 기존 구현체를 적응시킬 수 있는가?
    - 분석단계에서의 유비쿼터스 랭귀지 (업무현장에서 쓰는 용어) 를 사용하여 소스코드가 서술되었는가?
  - Request-Response 방식의 서비스 중심 아키텍처 구현
    - 마이크로 서비스간 Request-Response 호출에 있어 대상 서비스를 어떠한 방식으로 찾아서 호출 하였는가? (Service Discovery, REST, FeignClient)
    - 서킷브레이커를 통하여  장애를 격리시킬 수 있는가?
  - 이벤트 드리븐 아키텍처의 구현
    - 카프카를 이용하여 PubSub 으로 하나 이상의 서비스가 연동되었는가?
    - Correlation-key:  각 이벤트 건 (메시지)가 어떠한 폴리시를 처리할때 어떤 건에 연결된 처리건인지를 구별하기 위한 Correlation-key 연결을 제대로 구현 하였는가?
    - Message Consumer 마이크로서비스가 장애상황에서 수신받지 못했던 기존 이벤트들을 다시 수신받아 처리하는가?
    - Scaling-out: Message Consumer 마이크로서비스의 Replica 를 추가했을때 중복없이 이벤트를 수신할 수 있는가
    - CQRS: Materialized View 를 구현하여, 타 마이크로서비스의 데이터 원본에 접근없이(Composite 서비스나 조인SQL 등 없이) 도 내 서비스의 화면 구성과 잦은 조회가 가능한가?
  - 폴리글랏 플로그래밍
    - 각 마이크로 서비스들이 하나이상의 각자의 기술 Stack 으로 구성되었는가?
    - 각 마이크로 서비스들이 각자의 저장소 구조를 자율적으로 채택하고 각자의 저장소 유형 (RDB, NoSQL, File System 등)을 선택하여 구현하였는가?
  - API 게이트웨이
    - API GW를 통하여 마이크로 서비스들의 집입점을 통일할 수 있는가?
    - 게이트웨이와 인증서버(OAuth), JWT 토큰 인증을 통하여 마이크로서비스들을 보호할 수 있는가?

- 운영

  - SLA 준수
    - 셀프힐링: Liveness Probe 를 통하여 어떠한 서비스의 health 상태가 지속적으로 저하됨에 따라 어떠한 임계치에서 pod 가 재생되는 것을 증명할 수 있는가?
    - 서킷브레이커, 레이트리밋 등을 통한 장애격리와 성능효율을 높힐 수 있는가?
    - 오토스케일러 (HPA) 를 설정하여 확장적 운영이 가능한가?
    - 모니터링, 앨럿팅 
  - 무정지 운영 CI/CD (10)
    - Readiness Probe 의 설정과 Rolling update을 통하여 신규 버전이 완전히 서비스를 받을 수 있는 상태일때 신규버전의 서비스로 전환됨을 siege 등으로 증명 
    - Contract Test :  자동화된 경계 테스트를 통하여 구현 오류나 API 계약위반를 미리 차단 가능한가?


# 분석/설계


## AS-IS 조직 (Horizontally-Aligned)
  ![image](https://user-images.githubusercontent.com/31404198/125080475-ccab6900-e0ff-11eb-819f-7fdd7c12d9d6.png)

## TO-BE 조직 (Vertically-Aligned)
![image](https://user-images.githubusercontent.com/31404198/126869986-73db8772-bfef-4eb5-b3fc-b419cf96c4db.png)

## Event Storming 결과
* MSAEz 로 모델링한 이벤트스토밍 결과:  http://www.msaez.io/#/storming/qTPVkyZojONcrS0xJzeIbYjPXMl1/27b756dbbb9465a4669fe032c6c4fa13


### 이벤트 도출
![image](https://user-images.githubusercontent.com/31404198/126870009-e3aa366c-aa9b-4b18-b41e-cc715139a180.png)

### 부적격 이벤트 탈락
![image](https://user-images.githubusercontent.com/31404198/126870019-adaab60a-026e-419c-b97a-6fdf3c2b589e.png)

    - 과정중 도출된 잘못된 도메인 이벤트들을 걸러내는 작업을 수행함

### 액터, 커맨드 부착하여 읽기 좋게
![image](https://user-images.githubusercontent.com/31404198/126870025-ba220027-fcf2-405f-902a-51c7295405cb.png)

### 어그리게잇으로 묶기
![image](https://user-images.githubusercontent.com/31404198/126870034-bc8254da-1436-4f09-9fcf-8a0abe9bf7b4.png)

    - 전자책정보, 대여정보리, 결제정보는 그와 연결된 command 와 event 들에 의하여 트랜잭션이 유지되어야 하는 단위로 그들 끼리 묶어줌

### 바운디드 컨텍스트로 묶기

![image](https://user-images.githubusercontent.com/31404198/126870075-1da27fb8-3af1-4d28-8850-d098ef1ef40b.png)

    - 도메인 서열 분리 
        - Core Domain:  대여 : 없어서는 안될 핵심 서비스이며, 연견 Up-time SLA 수준을 99.999% 목표, 배포주기는 예약의 경우 1주일 1회 미만, 대여의 경우 1개월 1회 미만
        - Supporting Domain: 전자책관리   : 경쟁력을 내기위한 서비스이며, SLA 수준은 연간 60% 이상 uptime 목표, 배포주기는 각 팀의 자율이나 표준 스프린트 주기가 1주일 이므로 1주일 1회 이상을 기준으로 함.
        - General Domain:   결제 : 결제서비스로 3rd Party 외부 서비스를 사용하는 것이 경쟁력이 높음 (핑크색으로 이후 전환할 예정)

### 폴리시 부착 (괄호는 수행주체, 폴리시 부착을 둘째단계에서 해놔도 상관 없음. 전체 연계가 초기에 드러남)

![image](https://user-images.githubusercontent.com/31404198/126870098-d01f30cb-7bf9-450e-a5c6-4071bfd80ae2.png)

### 폴리시의 이동과 컨텍스트 매핑 (점선은 Pub/Sub, 실선은 Req/Resp)

![image](https://user-images.githubusercontent.com/31404198/126870109-8c11bc11-9119-4962-8c2b-19d2af8cc0e4.png)

### 완성된 1차 모형

![image](https://user-images.githubusercontent.com/31404198/126994453-8447db9c-f80e-40bf-ba56-4d039a6673b8.png)

    - View Model 추가

### 1차 완성본에 대한 기능적/비기능적 요구사항을 커버하는지 검증

![image](https://user-images.githubusercontent.com/31404198/126994548-d2e62c24-484e-4ba4-8916-22bd096abc3c.png)

    - 관리자가 전자책을 등록한다. (ok)

![image](https://user-images.githubusercontent.com/31404198/126994627-52c7cfe0-50e3-417c-8ffe-329051c0150f.png)

    - 회원이 전자책을 선택하여 대여 신청한다. (ok)
    - 회원이 결제한다. (ok)
    - 대여신청이 되면 신청내역이 관리자에게 전달된다. (ok)

![image](https://user-images.githubusercontent.com/31404198/126994715-63f05029-fb81-40de-9958-e51b79205837.png)

    - 관리자는 신청내역을 확인하고 대여승인한다. (ok)
    - 대여승인이 되면 회원은 대여가 시작된다. (ok)
    - 회원이 대여현황을 중간중간 조회한다. (View-green sticker 의 추가로 ok)

![image](https://user-images.githubusercontent.com/31404198/126994767-ab2561e1-9da0-4b3b-bf78-071314b89ea1.png)

    - 회원이 전자책을 반납한다. (ok)

![image](https://user-images.githubusercontent.com/31404198/126994835-f737a8b0-4172-4fab-896f-2291bc92f0d6.png)

    - 관리자는 신청내역을 확인하고 대여거절한다. (ok)
    - 대여거절이 되면 결제가 취소된다. (ok)
    - 결제가 취소되면 대여가 취소된다. (ok)

### 비기능 요구사항에 대한 검증

![image](https://user-images.githubusercontent.com/31404198/126994900-98b2b8e8-2564-450b-8adb-cd3f7fbd9587.png)

    - 마이크로 서비스를 넘나드는 시나리오에 대한 트랜잭션 처리
    - 고객 예약시 결제처리:  결제가 완료되지 않은 예약은 절대 대여를 할 수 없기 때문에, ACID 트랜잭션 적용. 예약완료시 결제처리에 대해서는 Request-Response 방식 처리
    - 결제 완료시 대여연결:  예약(front)에서 대여 마이크로서비스로 대여요청이 전달되는 과정에 있어서 대여 마이크로 서비스가 별도의 배포주기를 가지기 때문에 Eventual Consistency 방식으로 트랜잭션 처리함.
    - 나머지 모든 inter-microservice 트랜잭션: 예약상태, 대여상태 등 모든 이벤트에 대해 카톡을 처리하는 등, 데이터 일관성의 시점이 크리티컬하지 않은 모든 경우가 대부분이라 판단, Eventual Consistency 를 기본으로 채택함.

## 헥사고날 아키텍처 다이어그램 도출

![image](https://user-images.githubusercontent.com/31404198/126870296-57bd51e7-ca71-44e8-8683-d748062bb407.png)

    - Chris Richardson, MSA Patterns 참고하여 Inbound adaptor와 Outbound adaptor를 구분함
    - 호출관계에서 PubSub 과 Req/Resp 를 구분함
    - 서브 도메인과 바운디드 컨텍스트의 분리:  각 팀의 KPI 별로 아래와 같이 관심 구현 스토리를 나눠가짐

# 구현

- 분석/설계 단계에서 도출된 헥사고날 아키텍처에 따라, 각 BC별로 대변되는 마이크로 서비스들을 스프링부트로 구현하였다. 구현한 각 서비스를 로컬에서 실행하는 방법은 아래와 같다 (각자의 포트넘버는 8081 ~ 808n 이다)
```shell
  cd ebookmgmt-book
  mvn spring-boot:run
  
  cd ebookmgmt-rent
  mvn spring-boot:run
  
  cd ebookmgmt-payment
  mvn spring-boot:run
  
  cd ebookmgmt-dashboard
  mvn spring-boot:run
  
  cd ebookmgmt-gateway
  mvn spring-boot:run
```

## 게이트웨이 적용
```yml
  server:
    port: 8088
  
  ---
  
  spring:
    profiles: default
    cloud:
      gateway:
        routes:
          - id: ebookmgmt-rent
            uri: http://localhost:8081
            predicates:
              - Path=/rents/**
          - id: ebookmgmt-payment
            uri: http://localhost:8082
            predicates:
              - Path=/payments/**
          - id: ebookmgmt-book
            uri: http://localhost:8083
            predicates:
              - Path=/books/**
          - id: ebookmgmt-dashboard
            uri: http://localhost:8084
            predicates:
              - Path= /dashboards/**
        globalcors:
          corsConfigurations:
            '[/**]':
              allowedOrigins:
                - "*"
              allowedMethods:
                - "*"
              allowedHeaders:
                - "*"
              allowCredentials: true
  
  server:
    port: 8088
  
  ---
  
  spring:
    profiles: docker
    cloud:
      gateway:
        routes:
          - id: ebookmgmt-rent
            uri: http://user18-ebookmgmt-rent:8080
            predicates:
              - Path=/rents/**
          - id: ebookmgmt-payment
            uri: http://user18-ebookmgmt-payment:8080
            predicates:
              - Path=/payments/**
          - id: ebookmgmt-book
            uri: http://user18-ebookmgmt-book:8080
            predicates:
              - Path=/books/**
          - id: ebookmgmt-dashboard
            uri: http://user18-ebookmgmt-dashboard:8080
            predicates:
              - Path= /dashboards/**
        globalcors:
          corsConfigurations:
            '[/**]':
              allowedOrigins:
                - "*"
              allowedMethods:
                - "*"
              allowedHeaders:
                - "*"
              allowCredentials: true
  
  server:
    port: 8080
```
- ebookmgmt-gateway Service yml 에 loadBalancer 적용
```yml
  apiVersion: v1
  kind: Service
  metadata:
    name: user18-ebookmgmt-gateway
    labels:
      app: user18-ebookmgmt-gateway
  spec:
    ports:
      - port: 8080
        targetPort: 8080
    selector:
      app: user18-ebookmgmt-gateway
    type: LoadBalancer
```

## DDD 의 적용

- 각 서비스내에 도출된 핵심 Aggregate Root 객체를 Entity 로 선언하였다: (예시는 Payment 마이크로 서비스). 이때 가능한 현업에서 사용하는 언어 (유비쿼터스 랭귀지)를 그대로 사용하였다. 
```JAVA
  package ebookmanagement;
  
  import javax.persistence.*;
  import org.springframework.beans.BeanUtils;
  
  import java.util.Date;
  
  @Entity
  @Table(name="Payment_table")
  public class Payment {
  
      @Id
      @GeneratedValue(strategy=GenerationType.AUTO)
      private Long id;
      private Long rentId;
      private Long userId;
      private Long bookId;
      private Long rentalFee;
      private String status;
      private Date paidDate;
      private Date refundedDate;
  
      @PrePersist
      public void onPrePersist(){
          if("RENTED".equals(this.status)) {
              this.status = "PAID";
              this.paidDate = new Date();
          }
      }
  
      @PostPersist
      public void onPostPersist(){
          Paid paid = new Paid();
          BeanUtils.copyProperties(this, paid);
          paid.publishAfterCommit();
      }
  
      @PostUpdate
      public void onPostUpdate(){
          Refunded refunded = new Refunded();
          BeanUtils.copyProperties(this, refunded);
          refunded.publishAfterCommit();
      }
  
      public Long getId() {
          return id;
      }
  
      public void setId(Long id) {
          this.id = id;
      }
      public Long getRentId() {
          return rentId;
      }
  
      public void setRentId(Long rentId) {
          this.rentId = rentId;
      }
      public Long getUserId() {
          return userId;
      }
  
      public void setUserId(Long userId) {
          this.userId = userId;
      }
      public Long getBookId() {
          return bookId;
      }
  
      public void setBookId(Long bookId) {
          this.bookId = bookId;
      }
      public Long getRentalFee() {
          return rentalFee;
      }
  
      public void setRentalFee(Long rentalFee) {
          this.rentalFee = rentalFee;
      }
      public String getStatus() {
          return status;
      }
  
      public void setStatus(String status) {
          this.status = status;
      }
      public Date getPaidDate() {
          return paidDate;
      }
  
      public void setPaidDate(Date paidDate) {
          this.paidDate = paidDate;
      }
      public Date getRefundedDate() {
          return refundedDate;
      }
  
      public void setRefundedDate(Date refundedDate) {
          this.refundedDate = refundedDate;
      }
  }
```
- Entity Pattern 과 Repository Pattern 을 적용하여 JPA 를 통하여 다양한 데이터소스 유형 (RDB or NoSQL) 에 대한 별도의 처리가 없도록 데이터 접근 어댑터를 자동 생성하기 위하여 Spring Data REST 의 RestRepository 를 적용하였다
```JAVA
  package ebookmanagement;
  
  import org.springframework.data.repository.PagingAndSortingRepository;
  import org.springframework.data.rest.core.annotation.RepositoryRestResource;
  
  import java.util.Optional;
  
  @RepositoryRestResource(collectionResourceRel="books", path="books")
  public interface BookRepository extends PagingAndSortingRepository<Book, Long>{
      Optional<Book> findByRentId(Long rentId);
  }
```
- 적용 후 REST API 의 테스트
```shell
  # ebookmgmt-book 서비스의 도서등록 처리
  http POST http://localhost:8083/books bookName="Hello, JAVA" rentalFee=3000
  
  # ebookmgmt-rent 서비스의 예약신청 처리
  http POST http://localhost:8081/rents userId=1 bookId=1 bookName="Hello, JAVA" rentalFee=3000
  
  # 예약상태 확인
  http http://localhost:8081/rents/1
```

## 폴리글랏 퍼시스턴스
- CQRS 를 위한 Dashboard 서비스만 DB를 구분하여 적용함. 인메모리 DB인 hsqldb 사용.
```xml
  <!-- <dependency>
      <groupId>com.h2database</groupId>
      <artifactId>h2</artifactId>
      <scope>runtime</scope>
  </dependency> -->

  <dependency>
      <groupId>org.hsqldb</groupId>
      <artifactId>hsqldb</artifactId>
      <version>2.4.0</version>
      <scope>runtime</scope>
  </dependency>
```

## 동기식 호출 과 Fallback 처리
분석단계에서의 조건 중 하나로 예약신청(rent)->결제(payment) 간의 호출은 동기식 일관성을 유지하는 트랜잭션으로 처리하기로 하였다. 호출 프로토콜은 이미 앞서 Rest Repository 에 의해 노출되어있는 REST 서비스를 FeignClient 를 이용하여 호출하도록 한다.

- 결제서비스를 호출하기 위하여 Stub과 (FeignClient) 를 이용하여 Service 대행 인터페이스 (Proxy) 를 구현
```JAVA
# (ebookmgmt-rent) PaymentService.java

  package ebookmanagement.external;
  
  ...
  
  @FeignClient(name="ebookmgmt-payment", url="http://localhost:8082")//, fallback = PaymentServiceFallback.class)
  public interface PaymentService {
  
      @RequestMapping(method= RequestMethod.POST, path="/payments")
      public void payment(@RequestBody Payment payment);
  
  }
```
- 예약신청 직후(@PostPersist**) 결제를 요청하도록 처리
```JAVA
  # Rent.java (Entity)

  // 해당 엔티티 저장 후
  @PostPersist
  public void onPostPersist() {
      if("RENTED".equals(this.status)) {
          Rented rented = new Rented();
          BeanUtils.copyProperties(this, rented);
          rented.publish();

          ebookmanagement.external.Payment payment = new ebookmanagement.external.Payment();
          payment.setRentId(this.id);
          payment.setUserId(this.userId);
          payment.setBookId(this.bookId);
          payment.setRentalFee(this.rentalFee);

          EbookmgmtRentApplication.applicationContext.getBean(ebookmanagement.external.PaymentService.class)
                  .payment(payment);
      }
  }
```
- 동기식 호출에서는 호출 시간에 따른 타임 커플링이 발생하며, 결제 시스템이 장애가 나면 예약도 못받는다는 것을 확인
```shell
  # 결제(ebookmgmt-payment) 서비스를 잠시 내려놓음

  # 예약신청 처리
  http POST http://localhost:8081/rents userId=1 bookId=1 bookName="Hello, JAVA" rentalFee=3000  # Fail
```
![image](https://user-images.githubusercontent.com/31404198/126902989-4856a717-4973-43dc-9a24-e04ea7f3284d.png)
```shell
  # 결제서비스 재기동
  cd ebookmgmt-payment
  mvn spring-boot:run
```
```shell
  # 사용 신청 처리
  http POST http://localhost:8081/rents userId=1 bookId=1 bookName="Hello, JAVA" rentalFee=3000  #Success
```
![image](https://user-images.githubusercontent.com/31404198/126903049-77ccfce2-f696-48dd-bbe8-601da9628cba.png)

- 또한 과도한 요청시에 서비스 장애가 도미노처럼 벌어질 수 있다.

## 비동기식 호출 / 시간적 디커플링 / 장애격리 / 최종 (Eventual) 일관성 테스트
결제가 이루어진 후에 도서관리 시스템으로 이를 알려주는 행위는 동기식이 아니라 비동기식으로 처리하여 예약을 위하여 결제가 블로킹 되지 않도록 처리한다.

- 이를 위하여 결제시스템에 기록을 남긴 후에 곧바로 결제완료이 되었다는 도메인 이벤트를 카프카로 송출한다(Publish)
```JAVA
  package ebookmanagement;
  
  ...
  
  @Entity
  @Table(name="Payment_table")
  public class Payment {
  
      ...
      
      @PostPersist
      public void onPostPersist(){
          Paid paid = new Paid();
          BeanUtils.copyProperties(this, paid);
          paid.publishAfterCommit();
      }
  }
```
- 도서관리 서비스에서는 결제완료 이벤트에 대해서 이를 수신하여 자신의 정책을 처리하도록 PolicyHandler 를 구현한다:
```JAVA
  package ebookmanagement;
  
  ...
  
  @Service
  public class PolicyHandler{
  
      @StreamListener(KafkaProcessor.INPUT)
      public void wheneverPaid_ApproveRequest(@Payload Paid paid) {
  
          if(!paid.validate()) return;
  
          System.out.println("\n\n##### listener ApproveRequest : " + paid.toJson() + "\n\n");
  
      }
  }
```
- 실제 구현을 하자면, 결제후 예약요청이 오면 관리자는 예약승인 또는 거절처리를 UI에 입력할테니, 우선 예약정보를 DB에 받아놓은 후, 이후 처리는 해당 Aggregate 내에서 하면 되겠다.
```JAVA
  package ebookmanagement;
  
  ...
  
  @Service
  public class PolicyHandler{
      @Autowired BookRepository bookRepository;
  
      @StreamListener(KafkaProcessor.INPUT)
      public void wheneverPaid_ApproveRequest(@Payload Paid paid) {
  
          if(!paid.validate()) return;
  
          System.out.println("\n\n##### listener ApproveRequest : " + paid.toJson() + "\n\n");
  
          Long bookId = paid.getBookId();
          Long rentId = paid.getRentId();
          Long userId = paid.getUserId();
          String status = paid.getStatus();
  
          if("PAID".equals(status)) {
              Book book = bookRepository.findById(bookId).get();
              book.setId(bookId);
              book.setRentId(rentId);
              book.setUserId(userId);
              book.setStatus(status);
  
              bookRepository.save(book);
          }
      }
  }
```
- 도서관리 시스템은 예약/결제와 완전히 분리되어있으며, 이벤트 수신에 따라 처리되기 때문에, 도서관리가 유지보수로 인해 잠시 내려간 상태라도 예약신청을 받는데 문제가 없다:
```shell
  # 도서관리 서비스(ebookmgmt-book) 를 잠시 내려놓음
  # 예약신청 처리
```
![image](https://user-images.githubusercontent.com/31404198/126904180-f77e1a4f-fb24-428c-83b3-47ee46dd2389.png)
```shell
  # 예약신청 후 결제 처리 Event 진행확인
```
![image](https://user-images.githubusercontent.com/31404198/126904267-e481ad89-1566-467a-b9d0-b4756902261a.png)
```shell
  # 도서관리 서비스 기동
  cd ebookmgmt-book
  mvn spring-boot:run

  # 예약 상태 확인
```
![image](https://user-images.githubusercontent.com/31404198/126904371-e0ce8ef3-071f-4c2e-8f4c-c01ea8f82029.png)

## Correlation-key
- 도서등록, 예약신청, 예약승인, 도서반납 작업을 통해, Correlation-key 연결을 검증한다

```shell
  # 도서 등록 
```
![image](https://user-images.githubusercontent.com/31404198/126904636-74b13edd-5228-4814-9ef9-d54373d78e1a.png)
```shell
  # 예약 신청 
```
![image](https://user-images.githubusercontent.com/31404198/126904665-c18e84b3-3a57-483b-8ef2-96b651039c92.png)
```shell
  # 예약승인 처리
```
![image](https://user-images.githubusercontent.com/31404198/126904697-16674670-33d2-49e4-ac32-7d28431d471f.png)
```shell
  # 반납 처리
```
![image](https://user-images.githubusercontent.com/31404198/126904719-abbcea78-13a3-4f50-a287-38c10cd5f31e.png)
```shell
  # 도서내역과 예약내역 확인 ( 도서상태가 POSSIBLE로 초기화되고, 예약상태는 RETURNED로 변경됨 ) 
```
![image](https://user-images.githubusercontent.com/31404198/126904778-51914fa6-c8f2-4f30-85d7-7880a290a020.png)

![image](https://user-images.githubusercontent.com/31404198/126904791-188295bb-2629-42b3-94e0-0ba837ba1f9c.png)

## CQRS
CQRS: Materialized View 를 구현하여, 타 마이크로서비스의 데이터 원본에 접근없이(Composite 서비스나 조인SQL 등 없이) 도 내 서비스의 화면 구성과 잦은 조회가 가능하도록 구현한다
- 예약 / 결제서비스의 전체 현황 및 상태 조회를 제공하기 위해 dashboard를 구성하였다.
- dashboard의 어트리뷰트는 다음과 같다.
  ![image](https://user-images.githubusercontent.com/31404198/126904884-6d65287e-22a4-4118-ad02-c7fb4580b377.png)
```shell
  Rented, Paid, Approved, Returned, Canceled 이벤트에 따라 주문상태, 반납상태, 취소상태를 업데이트 하는 모델링을 진행하였다.
```
- 자동생성된 소스 샘플은 아래와 같다
```shell
  # Dashboard.java
```
```JAVA
  package ebookmanagement;
  
  import javax.persistence.*;
  import java.util.Date;
  
  @Entity
  @Table(name="Dashboard_table")
  public class Dashboard {
  
          @Id
          @GeneratedValue(strategy=GenerationType.AUTO)
          private Long id;
          private Long userId;
          private Long bookId;
          private String bookName;
          private Long rentalFee;
          private Date rentedDate;
          private Date paidDate;
          private Date returnedDate;
          private Date approvedDate;
          private String status;
          private Date canceledDate;
  
  
          public Long getId() {
              return id;
          }
  
          public void setId(Long id) {
              this.id = id;
          }
          public Long getUserId() {
              return userId;
          }
  
          public void setUserId(Long userId) {
              this.userId = userId;
          }
          public Long getBookId() {
              return bookId;
          }
  
          public void setBookId(Long bookId) {
              this.bookId = bookId;
          }
          public String getBookName() {
              return bookName;
          }
  
          public void setBookName(String bookName) {
              this.bookName = bookName;
          }
          public Long getRentalFee() {
              return rentalFee;
          }
  
          public void setRentalFee(Long rentalFee) {
              this.rentalFee = rentalFee;
          }
          public Date getRentedDate() {
              return rentedDate;
          }
  
          public void setRentedDate(Date rentedDate) {
              this.rentedDate = rentedDate;
          }
          public Date getPaidDate() {
              return paidDate;
          }
  
          public void setPaidDate(Date paidDate) {
              this.paidDate = paidDate;
          }
          public Date getReturnedDate() {
              return returnedDate;
          }
  
          public void setReturnedDate(Date returnedDate) {
              this.returnedDate = returnedDate;
          }
          public Date getApprovedDate() {
              return approvedDate;
          }
  
          public void setApprovedDate(Date approvedDate) {
              this.approvedDate = approvedDate;
          }
          public String getStatus() {
              return status;
          }
  
          public void setStatus(String status) {
              this.status = status;
          }
          public Date getCanceledDate() {
              return canceledDate;
          }
  
          public void setCanceledDate(Date canceledDate) {
              this.canceledDate = canceledDate;
          }
  }
```
```shell
  # DashboardRepository.java
```
```JAVA
  package ebookmanagement;
  
  import org.springframework.data.repository.CrudRepository;
  import org.springframework.data.repository.query.Param;
  
  import java.util.List;
  
  public interface DashboardRepository extends CrudRepository<Dashboard, Long> {
  
  
  }
```
```shell
  # DashboardViewHandler.java
```
```JAVA
  package ebookmanagement;
  
  import ebookmanagement.config.kafka.KafkaProcessor;
  import org.springframework.beans.factory.annotation.Autowired;
  import org.springframework.cloud.stream.annotation.StreamListener;
  import org.springframework.messaging.handler.annotation.Payload;
  import org.springframework.stereotype.Service;
  
  import java.util.Optional;
  
  @Service
  public class DashboardViewHandler {
  
    @Autowired
    private DashboardRepository dashboardRepository;
  
    @StreamListener(KafkaProcessor.INPUT)
    public void whenRented_then_CREATE_1 (@Payload Rented rented) {
      try {
  
        if (!rented.validate()) return;
  
        // view 객체 생성
        Dashboard dashboard = new Dashboard();
        // view 객체에 이벤트의 Value 를 set 함
        dashboard.setId(rented.getId());
        dashboard.setUserId(rented.getUserId());
        dashboard.setBookId(rented.getBookId());
        dashboard.setBookName(rented.getBookName());
        dashboard.setRentalFee(rented.getRentalFee());
        dashboard.setRentedDate(rented.getRentedDate());
        dashboard.setStatus(rented.getStatus());
        // view 레파지 토리에 save
        dashboardRepository.save(dashboard);
  
      }catch (Exception e){
        e.printStackTrace();
      }
    }
  
  
    @StreamListener(KafkaProcessor.INPUT)
    public void whenPaid_then_UPDATE_1(@Payload Paid paid) {
      try {
        if (!paid.validate()) return;
        // view 객체 조회
        Optional<Dashboard> dashboardOptional = dashboardRepository.findById(paid.getRentId());
  
        if( dashboardOptional.isPresent()) {
          Dashboard dashboard = dashboardOptional.get();
          // view 객체에 이벤트의 eventDirectValue 를 set 함
          dashboard.setPaidDate(paid.getPaidDate());
          dashboard.setStatus(paid.getStatus());
          dashboard.setRentalFee(paid.getRentalFee());
          // view 레파지 토리에 save
          dashboardRepository.save(dashboard);
        }
  
      }catch (Exception e){
        e.printStackTrace();
      }
    }
    @StreamListener(KafkaProcessor.INPUT)
    public void whenApproved_then_UPDATE_2(@Payload Approved approved) {
      try {
        if (!approved.validate()) return;
        // view 객체 조회
        Optional<Dashboard> dashboardOptional = dashboardRepository.findById(approved.getRentId());
  
        if( dashboardOptional.isPresent()) {
          Dashboard dashboard = dashboardOptional.get();
          // view 객체에 이벤트의 eventDirectValue 를 set 함
          dashboard.setApprovedDate(approved.getApprovedDate());
          dashboard.setRentedDate(approved.getApprovedDate());
          dashboard.setStatus(approved.getStatus());
          // view 레파지 토리에 save
          dashboardRepository.save(dashboard);
        }
  
      }catch (Exception e){
        e.printStackTrace();
      }
    }
    @StreamListener(KafkaProcessor.INPUT)
    public void whenReturned_then_UPDATE_3(@Payload Returned returned) {
      try {
        if (!returned.validate()) return;
        // view 객체 조회
        Optional<Dashboard> dashboardOptional = dashboardRepository.findById(returned.getId());
  
        if( dashboardOptional.isPresent()) {
          Dashboard dashboard = dashboardOptional.get();
          // view 객체에 이벤트의 eventDirectValue 를 set 함
          dashboard.setReturnedDate(returned.getReturnedDate());
          dashboard.setStatus(returned.getStatus());
          // view 레파지 토리에 save
          dashboardRepository.save(dashboard);
        }
  
  
      }catch (Exception e){
        e.printStackTrace();
      }
    }
    @StreamListener(KafkaProcessor.INPUT)
    public void whenCanceled_then_UPDATE_4(@Payload Canceled canceled) {
      try {
        if (!canceled.validate()) return;
        // view 객체 조회
        Optional<Dashboard> dashboardOptional = dashboardRepository.findById(canceled.getId());
  
        if( dashboardOptional.isPresent()) {
          Dashboard dashboard = dashboardOptional.get();
          // view 객체에 이벤트의 eventDirectValue 를 set 함
          dashboard.setStatus(canceled.getStatus());
          dashboard.setCanceledDate(canceled.getCanceledDate());
          // view 레파지 토리에 save
          dashboardRepository.save(dashboard);
        }
  
      }catch (Exception e){
        e.printStackTrace();
      }
    }
  
  }
```
- CQRS에 대한 테스트는 아래와 같다.
```shell
  예약신청 시 결제까지 정상적으로 수행 및 등록이 되며,
```
![image](https://user-images.githubusercontent.com/31404198/126905656-e9feb0dc-68c6-4b9d-872b-3a4d286f698b.png)
```shell
  dashbaord CQRS 결과는 아래와 같다.
```
![image](https://user-images.githubusercontent.com/31404198/126905688-8b656fe8-81c4-4478-89c4-14338273811a.png)

# 운영

## Deploy / Pipeline
각 구현체들은 각자의 source repository 에 구성되었고, 사용한 CI/CD 플랫폼은 AWS CodeBuild를 사용하였으며, pipeline build script 는 각 프로젝트 폴더 이하에 buildspec.yml 에 포함되었다.

- CodeBuild Pipeline
![image](https://user-images.githubusercontent.com/31404198/126937997-decef4f0-9d78-4c03-ac64-0170d90384cb.png)
  
- Github WebHook 연결
![image](https://user-images.githubusercontent.com/31404198/126934758-931e28fc-d88b-4698-aed2-27f35d7664dd.png)

```shell
  # ebookmgmt-book/buildspec.yml 파일
```
```YML
  version: 0.2
  
  env:
    variables:
      _PROJECT_NAME: "user18-ebookmgmt-book"
  
  phases:
    install:
      runtime-versions:
        java: corretto8
        docker: 18
      commands:
        - echo install kubectl
        - curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
        - chmod +x ./kubectl
        - mv ./kubectl /usr/local/bin/kubectl
    pre_build:
      commands:
        - echo Logging in to Amazon ECR...
        - echo $_PROJECT_NAME
        - echo $AWS_ACCOUNT_ID
        - echo $AWS_DEFAULT_REGION
        - echo $CODEBUILD_RESOLVED_SOURCE_VERSION
        - echo start command
        - $(aws ecr get-login --no-include-email --region $AWS_DEFAULT_REGION)
    build:
      commands:
        - echo Build started on `date`
        - echo Building the Docker image...
        - mvn package -Dmaven.test.skip=true
        - docker build -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$_PROJECT_NAME:$CODEBUILD_RESOLVED_SOURCE_VERSION  .
    post_build:
      commands:
        - echo Build completed on `date`
        - echo Pushing the Docker image...
        - docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$_PROJECT_NAME:$CODEBUILD_RESOLVED_SOURCE_VERSION
        - echo connect kubectl
        - kubectl config set-cluster k8s --server="$KUBE_URL" --insecure-skip-tls-verify=true
        - kubectl config set-credentials admin --token="$KUBE_TOKEN"
        - kubectl config set-context default --cluster=k8s --user=admin
        - kubectl config use-context default
        - |
          cat <<EOF | kubectl apply -f -
          apiVersion: v1
          kind: Service
          metadata:
            name: $_PROJECT_NAME
            labels:
              app: $_PROJECT_NAME
          spec:
            ports:
              - port: 8080
                targetPort: 8080
            selector:
              app: $_PROJECT_NAME
          EOF
        - |
          cat  <<EOF | kubectl apply -f -
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: $_PROJECT_NAME
            labels:
              app: $_PROJECT_NAME
          spec:
            replicas: 1
            selector:
              matchLabels:
                app: $_PROJECT_NAME
            template:
              metadata:
                labels:
                  app: $_PROJECT_NAME
              spec:
                containers:
                  - name: $_PROJECT_NAME
                    image: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$_PROJECT_NAME:$CODEBUILD_RESOLVED_SOURCE_VERSION
                    ports:
                      - containerPort: 8080
                    readinessProbe:
                      httpGet:
                        path: /actuator/health
                        port: 8080
                      initialDelaySeconds: 10
                      timeoutSeconds: 2
                      periodSeconds: 5
                      failureThreshold: 10
                    livenessProbe:
                      httpGet:
                        path: /actuator/health
                        port: 8080
                      initialDelaySeconds: 120
                      timeoutSeconds: 2
                      periodSeconds: 5
                      failureThreshold: 5
          EOF
  cache:
    paths:
      - '/root/.m2/**/*'
```
- Deploy 완료
![image](https://user-images.githubusercontent.com/31404198/126938103-6d32247c-e5e7-48d3-a60d-f6a58f1855c4.png)

## 동기식 호출 / 서킷 브레이킹 / 장애격리
- 서킷 브레이킹 프레임워크의 선택: Spring FeignClient + Hystrix 옵션을 사용하여 구현함
  시나리오는 예약신청(rent)-->결제(payment) 시 RESTful Request/Response 로 구현되어 있고
  결제 요청이 과도할 경우 CB 를 통하여 장애격리.
- Hystrix 를 설정: 요청처리 쓰레드에서 처리시간이 610 밀리가 넘어서기 시작하여 어느정도 유지되면 CB 회로가 닫히도록 (요청을 빠르게 실패처리, 차단) 설정
```yml
  # ebookmgmt-rent/application.yml
  
  feign:
    hystrix:
      enabled: true
  hystrix:
    command:
      default:
        execution.isolation.thread.timeoutInMilliseconds: 610
```
- 피호출 서비스(결제:payment) 의 부하 처리
```JAVA
  @PrePersist
  public void onPrePersist(){

      // 강제 Delay
      try {
          Thread.currentThread().sleep((long) (400 + Math.random() * 220));
      } catch (InterruptedException e) {
          e.printStackTrace();
      }

      ...
  }
```
- 부하테스터 siege 툴을 통한 서킷 브레이커 동작 확인
- 동시사용자 100명
- 60초 동안 실시
```shell
  $ siege -v -c100 -t60S -r10 --content-type "application/json" 'http://user18-ebookmgmt-rent:8080/rents POST {"userId":1, "bookId":1, "bookName":"Hello, JAVA", "rentalFee":3000}'
```
![image](https://user-images.githubusercontent.com/31404198/126951700-e30cb269-064b-4114-a186-1c55e5d88ef4.png)
![image](https://user-images.githubusercontent.com/31404198/126951598-c2fd54a0-5166-4ad6-bf36-711df0d25d43.png)
- 운영시스템은 죽지 않고 지속적으로 CB 에 의하여 적절히 회로가 열림과 닫힘이 벌어지면서 자원을 보호하고 있음을 보여줌. 하지만, 76.56% 가 성공하였고, 23.44%가 실패했다는 것은 고객 사용성에 있어 좋지 않기 때문에 동적 Scale out (replica의 자동적 추가,HPA) 을 통하여 시스템을 확장 해주는 후속처리가 필요.

## 오토스케일 아웃
앞서 CB 는 시스템을 안정되게 운영할 수 있게 해줬지만 사용자의 요청을 100% 받아들여주지 못했기 때문에 이에 대한 보완책으로 자동화된 확장 기능을 적용하고자 한다.

- (Spring FeignClient + Hystrix 적용한 경우) 위에서 설정된 CB는 제거
- 오토스케일 아웃 테스트를 위해 kubernetes/ebookmgmt-payment.yml 또는 ebookmgmt-payment/buildspec.yml에 메모리 설정 추가
```yaml
  resources:
    limits:
      cpu: 500m
    requests:
      cpu: 200m
```
- 결제서비스에 대한 replica 를 동적으로 늘려주도록 HPA 를 설정한다. 설정은 CPU 사용량이 15프로를 넘어서면 replica 를 10개까지 늘려준다.
```shell
  $ kubectl autoscale deploy user18-ebookmgmt-payment --min=1 --max=10 --cpu-percent=15
```
- 오토스케일이 어떻게 되고 있는지 모니터링을 걸어둔다. 
```shell
  $ kubectl get deploy user18-ebookmgmt-payment -w
```
- CB 에서 했던 방식대로 워크로드를 2분 동안 걸어준다.
```shell
  $ siege -v -c100 -t120S -r10 --content-type "application/json" 'http://user18-ebookmgmt-rent:8080/rents POST {"userId":1, "bookId":1, "bookName":"Hello, JAVA", "rentalFee":3000}'
```
- 어느정도 시간이 흐른 후 스케일 아웃이 벌어지는 것을 확인할 수 있다.
![image](https://user-images.githubusercontent.com/31404198/126983948-a3b325aa-4da8-4bee-a0f7-42e40ab93693.png)
![image](https://user-images.githubusercontent.com/31404198/126981126-926a111a-43f5-46cd-bca1-259aafebcdb4.png)
- Siege의 로그를 보아도 전체적인 성공율이 높아진 것을 확인할 수 있다.
![image](https://user-images.githubusercontent.com/31404198/126984210-8a61a971-61c1-4780-925a-c0f997217f21.png)

## 무정지 재배포(Readiness Probe)
- 먼저 무정지 재배포가 100% 되는 것인지 확인하기 위해서 Autoscaler 이나 CB 설정을 제거함
- siege 로 배포작업 직전에 워크로드를 모니터링 함.
```shell
  $ siege -v -c100 -t120S -r10 --content-type "application/json" 'http://user18-ebookmgmt-rent:8080/rents POST {"userId":1, "bookId":1, "bookName":"Hello, JAVA", "rentalFee":3000}'
```
- 새버전으로의 배포 시작 (웹훅이 적용된 CodeBuild를 사용하기 때문에 소스 수정 후 push 하여 배포)
```shell
  # command의 경우
  $ kubectl set image ...
```
- siege 의 화면으로 넘어가서 Availability 가 100% 미만으로 떨어졌는지 확인
![image](https://user-images.githubusercontent.com/31404198/126987955-f461a0d1-bc50-4efb-a5e9-5bb7cd4fdefd.png)
![image](https://user-images.githubusercontent.com/31404198/126987989-6e0c192b-280e-408b-b5c3-8ef83c63e57d.png)

- 배포기간중 Availability 가 평소 100%에서 90% 대로 떨어지는 것을 확인. 원인은 쿠버네티스가 성급하게 새로 올려진 서비스를 READY 상태로 인식하여 서비스 유입을 진행한 것이기 때문. 이를 막기위해 Readiness Probe 를 설정함.
```yaml
  # kubernetes/ebookmgmt-rent.yml 또는 ebookmgmt-rent/buildspec.yml에 설정 추가
  
  readinessProbe:
    httpGet:
      path: /actuator/health
      port: 8080
    initialDelaySeconds: 10
    timeoutSeconds: 2
    periodSeconds: 5
    failureThreshold: 10
```
- 동일한 시나리오로 재배포 한 후 Availability 확인:
![image](https://user-images.githubusercontent.com/31404198/126989260-0eccdfb4-962b-4a62-8068-98d7600edccd.png)

- 배포기간 동안 Availability 가 변화없기 때문에 무정지 재배포가 성공한 것으로 확인됨.

## Config Map
- 변경 가능성이 있는 설정을 ConfigMap을 사용하여 관리


    ebookmgmt-rent 서비스에서 바라보는 ebookmgmt-payment 서비스 url 일부분을 ConfigMap 사용하여 구현​
    ebookmgmt-rent 서비스 내 FeignClient (/external/PaymentService.java)

```java
  @FeignClient(name="user18-ebookmgmt-payment", url="${api.url.payment}")//, fallback = PaymentServiceFallback.class)
  public interface PaymentService {
  
    @RequestMapping(method= RequestMethod.POST, path="/payments")
    public void payment(@RequestBody Payment payment);
  
  }
```
- kubernetes/ebookmgmt-rent.yml 또는 ebookmgmt-rent/buildspec.yml
```yml
  # ConfigMap 설정
  apiVersion: v1
  kind: ConfigMap
  metadata:
    name: $_PROJECT_NAME-configmap
  data:
    api.url.payment: http://user18-ebookmgmt-payment:8080

  # ConfigMap 사용
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: $_PROJECT_NAME
    labels:
      app: $_PROJECT_NAME
  spec:
    ...
      spec:
        containers:
          - name: $_PROJECT_NAME
            ...
            env:
              - name: api.url.payment
                valueFrom:
                  configMapKeyRef:
                    name: $_PROJECT_NAME-configmap
                    key: api.url.payment
            ...
  EOF
```
- 적용 후 상세내역 확인 가능
```shell
  $ kubectl get configmap -o yaml
```
![image](https://user-images.githubusercontent.com/31404198/126993203-e7d3566e-1280-4bcd-8af3-321fa80ad1bd.png)
```shell
  $ kubectl describe pod/user18-ebookmgmt-rent-689bb44d85-sgtr2
```
![image](https://user-images.githubusercontent.com/31404198/126993401-2c0fb82b-1458-46da-b9af-7f1de89612c8.png)

## Self-healing (Liveness Probe)
- kubernetes/ebookmgmt-rent.yml 또는 ebookmgmt-rent/buildspec.yml 수정


    컨테이너 실행 후 /tmp/healthy 파일을 만들고
    90초 후 삭제
    livenessProbe에 'cat /tmp/healthy'으로 검증하도록 함

```yml
  apiVersion: apps/v1
  kind: Deployment
  ...
  args:
    - /bin/sh
    - -c
    - touch /tmp/healty; sleep 90; rm -rf /tmp/healthy; sleep 600
  ...
  livenessProbe:
#    httpGet:
#      path: /actuator/health
#      port: 8080
    exec:
      command:
        - cat
        - /tmp/healthy
    initialDelaySeconds: 120
    timeoutSeconds: 2
    periodSeconds: 5
    failureThreshold: 5
```

- 컨테이너 실행 후 90초 동인은 정상이나 이후 /tmp/healthy 파일이 삭제되어 livenessProbe에서 실패를 리턴하게 되고, restarts 카운트가 증가함
```shell
  $ kubectl get pod -o wide
```
![image](https://user-images.githubusercontent.com/31404198/127079317-dbb91e99-ed32-4e9c-9465-6a8229e28b21.png)

```shell
  $ kubectl describe pod/user18-ebookmgmt-rent
```
![image](https://user-images.githubusercontent.com/31404198/127079513-dc910163-750e-4c64-a7cb-02cb527fdcd7.png)

- pod 정상 상태 일때 pod 진입하여 /tmp/healthy 파일 생성해주면 정상 상태 유지되어 더이상 restarts 카운트가 증가하지 않음
![image](https://user-images.githubusercontent.com/31404198/127080403-6fd5baa1-cce4-4f0d-a4de-dabbfb7808ea.png)
![image](https://user-images.githubusercontent.com/31404198/127080529-7ca36ddb-0820-4c71-b1e7-33f9b96c27e3.png)
