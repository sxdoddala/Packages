

 /************************************************************************************
        Program Name: kbdx_gencost_data 

        Description:   

        Developed by : 
        Date         :  

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    RXNETHI(ARGANO)            1.0      05-May-2023      R12.2 Upgrade Remediation
    ****************************************************************************************/


create or replace package body kbdx_gencost_data as

Procedure main(errbuf OUT varchar2,
               retcode OUT number,
               p_eff_date in Varchar2,
               p_threads IN number ) IS

l_thread_master_id Number;
l_start_date Date;
TYPE number_tbl_type IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
request_id_tbl number_tbl_type; -- holds request id's for each thread
l_wait boolean;
l_phase varchar2(80);
l_status varchar2(80);
l_dev_phase varchar2(80);
l_dev_status varchar2(80);
l_message varchar2(80);

Begin
  --
  errbuf := null;
  retcode := 0;
  --
  SELECT /*+ RULE*/ xkb_thread_master_seq.nextval
  INTO   l_thread_master_id
  FROM   dual;

  -- Insert header information
  INSERT INTO xkb_thread_masters ( thread_master_id, status, creation_date)
  VALUES (l_thread_master_id, 'P', sysdate );
  COMMIT;

  l_start_date := kbdx_process_pkg.convert_date(p_date => p_eff_date);

  insert into xkb_threads (thread_number, status,message_text,source_id,thread_master_id)
  select /*+ RULE*/ 0,'U','',a.assignment_action_id,l_thread_master_id
  from pay_assignment_actions a, pay_payroll_actions p
  where a.action_status = 'C'
  and a.payroll_action_id= p.payroll_action_id
  and p.action_type  = 'C'
  and p.effective_date >=  l_start_date
  and not exists (select 1 from kbace.kbdx_costing_recon r
                  where r.assignment_action_id = a.assignment_action_id);
  commit;

   execute immediate 'truncate table kbace.kbdx_costing_recon';

  -- Loop through table and kickoff concurrent processes
  For i in 1..p_threads loop
    request_id_tbl(i) := fnd_request.submit_request(application => 'KBACE',
                                                    program => 'KBDXCSTGENT',
                                                    sub_request => FALSE,
                                                    argument1 => to_char(i),
                                                    argument2 => to_char(l_thread_master_id));
    if ( request_id_tbl(i) <= 0 ) then
		errbuf := substr('Failed to submit thread process.  Thread number = '||i||', Thread Master ID = '||l_thread_master_id||'.',1,250);
        retcode := 1;
    end if;
    --
    Commit;
  End Loop;
  -- Loop through the table again and wait for each thread to complete
  For i in 1 .. p_threads Loop
    l_wait := fnd_concurrent.wait_for_request(request_id_tbl(i),
                                              15,
                                              0,
                                              l_phase,
			                                  l_status,
                                              l_dev_phase,
                                              l_dev_status,
                                              l_message);
  End Loop;
  -- Update the thread master as completed
  UPDATE xkb_thread_masters SET status = 'C'
  WHERE  thread_master_id = l_thread_master_id;
  Commit;
End main;
-- Called from concurrent manager.
PROCEDURE cost_thread(errbuf OUT varchar2,
                               retcode OUT number,
                               p_thread IN number,
                               p_thread_master IN number) IS
err Varchar2(2000);

l_source_id number;

l_iv_id Number;
l_valid BOOLEAN := FALSE;

cursor drv(c_thread number, c_thread_master Number) is
select /*+ RULE*/ * From xkb_threads
where thread_number= c_thread
and thread_master_id = c_thread_master
and status = 'P';

cursor get_costing(c_asg_action_id Number) is
select /*+ RULE*/ c.costed_value, c.input_value_id, c.cost_id, c.debit_or_credit, c.run_result_id, c.distributed_input_value_id
from pay_run_result_values v, pay_run_results r, pay_costs c
where v.run_result_id = r.run_result_id
and c.input_value_id = v.input_value_id+0
and c.run_result_id =  r.run_result_id
and c.balance_or_cost = 'C'
and c.costed_value <> 0
and c.assignment_action_id = c_asg_action_id;

Begin
  Loop
    Begin
      update xkb_threads
      set thread_number = p_thread, status = 'P'
      where thread_number = 0
      and thread_master_id = p_thread_master
      and status = 'U'
      and rownum < 20;

      Exit When SQL%ROWCOUNT = 0;
      commit;

      For d in drv(p_thread, p_thread_master) Loop
        l_source_id := d.source_id;
        For i in get_costing(d.source_id) Loop
      --
      -- RR 11/14/2002 - Handle distributed costing.  Set the input value id to the distributed id and ignore the records
      --                 where the input_value_id = the distributed input_value_id
      --
          If nvl(i.distributed_input_value_id,i.input_value_id ) <> i.input_value_id Then
            l_iv_id := i.distributed_input_value_id;
            l_valid := TRUE;
          ElsIf i.distributed_input_value_id is null Then
            l_iv_id := i.input_value_id;
            l_valid := TRUE;
          Else  l_valid := FALSE;
          End If;
          If l_valid Then
            kbdx_costing_recon_pkg.log_costing_results (p_input_value_id => l_iv_id ,
  	    			                              p_run_result_id  => i.run_result_id,
                				                  p_cost_id => i.cost_id,
				                    	          p_debit_or_credit => i.debit_or_credit,
                    					          p_costed_value => i.costed_value,
                    					          p_operation => 'I');
            Commit;
          End If;
        End Loop;
  	  update xkb_threads
	  set status = 'C'
      where thread_master_id = p_thread_master
	  and thread_number = p_thread
      and source_id = d.source_id
      and status = 'P';
      Commit;
      End Loop;
      Exception
        When OTHERS Then
  	    err := sqlerrm;
   	    update xkb_threads
	    set status = 'E', message_text = err
	    where thread_master_id = p_thread_master
	    and thread_number = p_thread
        and source_id = l_source_id
	    and status = 'P';
	    Commit;
    End;
  End Loop;
  Commit;
End cost_thread;

End kbdx_gencost_data;
/
show errors;
/