<%@ Page Language="C#" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    Response.ContentType = "application/json";
    Response.Charset = "utf-8";
    
    try
    {
        string body = new StreamReader(Request.InputStream).ReadToEnd();
        
        if (string.IsNullOrEmpty(body))
        {
            Response.Write("{\"status\":\"error\",\"message\":\"بدون داده\"}");
            return;
        }

        var js = new JavaScriptSerializer();
        dynamic data = js.DeserializeObject(body);

        if (data == null || !data.ContainsKey("order_id") || !data.ContainsKey("items"))
        {
            Response.Write("{\"status\":\"error\",\"message\":\"داده‌های ناقص\"}");
            return;
        }

        if (data["items"] == null || !(data["items"] is System.Collections.ArrayList))
        {
            Response.Write("{\"status\":\"error\",\"message\":\"آیتم‌ها نامعتبر است\"}");
            return;
        }

        var items = (System.Collections.ArrayList)data["items"];
        if (items.Count == 0)
        {
            Response.Write("{\"status\":\"error\",\"message\":\"هیچ آیتمی وجود ندارد\"}");
            return;
        }

        // رشته اتصال مطابق با get_kalas.aspx
        string connectionString = "Server=194.5.195.93;Database=millionaire;User Id=sa;Password=2901;";

        using (SqlConnection conn = new SqlConnection(connectionString))
        {
            conn.Open();

            // ===== INSERT INTO buy_title =====
            SqlCommand cmd = new SqlCommand(@"
INSERT INTO dbo.buy_title
(NoFact,DateFact,SharhFact,CodeMF,SubF,Flag,codet,time1,DateSarResid,
khadamat,darsadarzesh,poolarzesh,darsadmalit,poolmalit,Imaliatkasr,
flagtasvietemp,flagtasvie,flagtasvietempanbar,SabtOkInt,
subTedad,subPool,subNaghd,nofactExcel,codep,RealNoFact,FLAGERSAL)
VALUES
(@NoFact,@DateFact,@SharhFact,@CodeMF,@SubF,'WC',1,GETDATE(),@DateSarResid,
0,0,0,0,0,0,'0','0','0',1,
@subTedad,@subPool,@subNaghd,@nofactExcel,@codep,@RealNoFact,'0')", conn);

            cmd.Parameters.AddWithValue("@NoFact", data["order_id"].ToString());
            cmd.Parameters.AddWithValue("@DateFact", DateTime.Now.ToString("yyyy/MM/dd"));
            cmd.Parameters.AddWithValue("@DateSarResid", DateTime.Now.ToString("yyyy/MM/dd"));
            cmd.Parameters.AddWithValue("@SharhFact", data.ContainsKey("customer") ? data["customer"].ToString().Trim() : "");
            cmd.Parameters.AddWithValue("@CodeMF", data.ContainsKey("mobile") ? data["mobile"].ToString().Trim() : "");
            cmd.Parameters.AddWithValue("@SubF", Convert.ToDecimal(data.ContainsKey("total") ? data["total"] : "0"));
            cmd.Parameters.AddWithValue("@subTedad", items.Count);
            cmd.Parameters.AddWithValue("@subPool", Convert.ToDecimal(data.ContainsKey("total") ? data["total"] : "0"));
            cmd.Parameters.AddWithValue("@subNaghd", Convert.ToDecimal(data.ContainsKey("total") ? data["total"] : "0"));
            cmd.Parameters.AddWithValue("@nofactExcel", data["order_id"].ToString());
            cmd.Parameters.AddWithValue("@codep", data.ContainsKey("email") ? data["email"].ToString().Trim() : "");
            cmd.Parameters.AddWithValue("@RealNoFact", data["order_id"].ToString());
            
            cmd.ExecuteNonQuery();

            // ===== INSERT INTO buy_detaile =====
            int radif = 1;
            foreach (Dictionary<string, object> item in items)
            {
                SqlCommand cmdDetail = new SqlCommand(@"
INSERT INTO dbo.buy_detaile
(NoFact,codeK,NoAnbar,Radif,Sharh,Tedad,Pool,price_sale,SabtOkInt,datetimex)
VALUES
(@NoFact,@codeK,1,@Radif,@Sharh,@Tedad,@Pool,@price_sale,1,GETDATE())", conn);

                cmdDetail.Parameters.AddWithValue("@NoFact", data["order_id"].ToString());
                cmdDetail.Parameters.AddWithValue("@codeK", item.ContainsKey("sku") ? item["sku"].ToString().Trim() : "");
                cmdDetail.Parameters.AddWithValue("@Radif", radif++);
                cmdDetail.Parameters.AddWithValue("@Sharh", item.ContainsKey("name") ? item["name"].ToString().Trim() : "");
                cmdDetail.Parameters.AddWithValue("@Tedad", item.ContainsKey("qty") ? Convert.ToInt32(item["qty"]) : 0);
                cmdDetail.Parameters.AddWithValue("@Pool", item.ContainsKey("total") ? Convert.ToDecimal(item["total"]) : 0);
                cmdDetail.Parameters.AddWithValue("@price_sale", item.ContainsKey("price") ? Convert.ToDecimal(item["price"]) : 0);
                
                cmdDetail.ExecuteNonQuery();
            }
        }

        Response.Write("{\"status\":\"ok\",\"message\":\"سفارش با موفقیت ذخیره شد\"}");
    }
    catch (SqlException sqlEx)
    {
        Response.Write("{\"status\":\"error\",\"message\":\"خطای SQL: " + sqlEx.Message.Replace("\"", "'").Replace("\r\n", " ") + "\"}");
    }
    catch (Exception ex)
    {
        Response.Write("{\"status\":\"error\",\"message\":\"خطا: " + ex.Message.Replace("\"", "'").Replace("\r\n", " ") + "\"}");
    }
}
</script>
