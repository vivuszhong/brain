-- ###### 查看被锁进程 ######
select 标志,
 进程ID=spid,线程ID=kpid,块进程ID=blocked,数据库ID=dbid,
 数据库名=db_name(dbid),用户ID=uid,用户名=loginame,累计CPU时间=cpu,
 登陆时间=login_time,打开事务数=open_tran, 进程状态=status,
 工作站名=hostname,应用程序名=program_name,工作站进程ID=hostprocess,
 域名=nt_domain,网卡地址=net_address
from(
 select 标志='死锁的进程',
  spid,kpid,a.blocked,dbid,uid,loginame,cpu,login_time,open_tran,
  status,hostname,program_name,hostprocess,nt_domain,net_address,
  s1=a.spid,s2=0
 from master..sysprocesses a join (
  select blocked from master..sysprocesses group by blocked
  )b on a.spid=b.blocked where a.blocked=0
 union all
 select '|_牺牲品_>',
  spid,kpid,blocked,dbid,uid,loginame,cpu,login_time,open_tran,
  status,hostname,program_name,hostprocess,nt_domain,net_address,
  s1=blocked,s2=1
 from master..sysprocesses a where blocked<>0
)a order by s1,s2

-- 查询锁对象
SELECT str (request_session_id, 4, 0) AS spid,
       CONVERT (VARCHAR (20), DB_NAME (resource_database_id)) AS db_name,
       CASE
          WHEN resource_database_id = DB_ID () AND resource_type = 'OBJECT'
          THEN
             CONVERT (CHAR (20), OBJECT_NAME (resource_associated_entity_id))
          ELSE
             CONVERT (CHAR (20), resource_associated_entity_id)
       END
          AS object,
       CONVERT (VARCHAR (12), resource_type) AS resource_type,
       CONVERT (VARCHAR (12), request_type) AS request_type,
       CONVERT (CHAR (3), request_mode) AS mode,
       CONVERT (VARCHAR (8), request_status) AS status
  FROM sys.dm_tran_locks
 WHERE resource_type = 'OBJECT'
ORDER BY 1, 3 DESC

exec sp_lock

EXEC sp_who active

SELECT @@LOCK_TIMEOUT


-- ###### 查first()记录 ######
-- 方法一
SELECT *
  FROM infu_master i
 WHERE i.infu_master_id =
          (SELECT TOP 1 im.infu_master_id
             FROM infu_master im
            WHERE     im.infu_status IN ('R', 'I', 'S')
                  AND im.pati_id = i.pati_id
           ORDER BY im.infu_master_id ASC)
-- 方法二
SELECT *
  FROM infu_master i
 WHERE i.infu_master_id IN (SELECT min (im.infu_master_id) AS infu_master_id
                              FROM infu_master im
                             WHERE im.infu_status IN ('R', 'I', 'S')
                            GROUP BY im.pati_id)
-- 方法三
SELECT *
  FROM (SELECT im.*,
               ROW_NUMBER ()
                  OVER (PARTITION BY im.pati_id ORDER BY im.infu_master_id)
                  RN
          FROM infu_master im
         WHERE im.infu_status IN ('R', 'I', 'S')) t
 WHERE t.RN = 1


-- ###### 查引起死锁的操作 ######
USE master
go
DECLARE @spid   INT
--查询出死锁的SPID
SELECT @spid = blocked
FROM (SELECT *
        FROM sysprocesses
       WHERE blocked > 0) a
WHERE NOT EXISTS
         (SELECT *
            FROM (SELECT *
                    FROM sysprocesses
                   WHERE blocked > 0) b
           WHERE a.blocked = spid)
--输出引起死锁的操作
DBCC INPUTBUFFER (@spid)
--exec sp_who2

use master
go
declare @spid int,@bl int
DECLARE s_cur CURSOR FOR 
select  0 ,blocked
from (select * from sysprocesses where  blocked>0 ) a 
where not exists(select * from (select * from sysprocesses where  blocked>0 ) b 
where a.blocked=spid)
union select spid,blocked from sysprocesses where  blocked>0
OPEN s_cur
FETCH NEXT FROM s_cur INTO @spid,@bl
WHILE @@FETCH_STATUS = 0
begin
if @spid =0 
select '引起数据库死锁的是: 
'+ CAST(@bl AS VARCHAR(10)) + '进程号,其执行的SQL语法如下'
else
select '进程号SPID：'+ CAST(@spid AS VARCHAR(10))+ '被' + '
进程号SPID：'+ CAST(@bl AS VARCHAR(10)) +'阻塞,其当前进程执行的SQL语法如下'
DBCC INPUTBUFFER (@bl )
FETCH NEXT FROM s_cur INTO @spid,@bl
end
CLOSE s_cur
DEALLOCATE s_cur


-- ###### 查事务隔离级别 ######
SELECT session_id,
       (CASE transaction_isolation_level
           WHEN 1 THEN 'ReadUncomitted'
           WHEN 2 THEN 'ReadCommitted'
           WHEN 3 THEN 'Repeatable'
           WHEN 4 THEN 'Serializable'
           WHEN 5 THEN 'Snapshot'
        END)
          [transaction_isolation_level]
  FROM sys.dm_exec_sessions
 WHERE session_id = @@SPID;

 DBCC USEROPTIONS


select * FROM sys.dm_tran_locks;

select * from sys.partitions;

select * from sys.objects so where so.schema_id = 1 order by [type];

select * from sys.sysdatabases

select * from sys.databases;

select * from sys.schemas;


