public class approvedPaypalController {

    public approvedPaypalController() {
        payPalApproved();
    }

    public List<Paypal_obj__c> paypalApprovedList { get; set; }

    public void payPalApproved() {
        paypalApprovedList = new List<Paypal_obj__c>();
        paypalApprovedList = [SELECT id, Paypal_email__c, paypal_amount__c, paypal_status__c FROM Paypal_obj__c LIMIT 250 FOR UPDATE];
    }
    
    public void pay() {
        // This is the killer method call:
        if(makePayment())
        {
            for(Paypal_obj__c pp: paypalApprovedList)
            {
                if(pp.paypal_status__c == 'Unpaid') {
                    pp.paypal_status__c = 'Sent';
                }
            }
            update(paypalApprovedList);
        }  
    }
    
    public boolean makePayment() {
        PaypalProcessor p = new PaypalProcessor();
        boolean payResult;
        if(Test.isRunningTest())
        {
            payResult= true;    
        }
        else
        {
            payResult = p.processNewPayments();
        }
        if(payResult)
        {
            apexpages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, 'Success'));
            return true;
        }
        else
        {
            apexpages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Failure'));
            return false;
        }
    }

}