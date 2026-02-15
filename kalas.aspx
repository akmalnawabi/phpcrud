<%@ Page Language="C#" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>
<%@ Import Namespace="System.Configuration" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    Response.ContentType = "application/json; charset=utf-8";
    Response.Charset = "utf-8";
    
    try
    {
        // خواندن Connection String از web.config
        string connectionString = string.Format(
            "Server={0};Database={1};User Id={2};Password={3};",
            ConfigurationManager.AppSettings["DbServer"],
            ConfigurationManager.AppSettings["DbName"],
            ConfigurationManager.AppSettings["DbUser"],
            ConfigurationManager.AppSettings["DbPassword"]
        );

        var items = new System.Collections.Generic.List<object>();
        
        using (SqlConnection conn = new SqlConnection(connectionString))
        {
            conn.Open();
            
            // کوئری گرفتن کالاها - همه ستون‌های مورد نیاز
            string query = @"
                SELECT 
                    codek,
                    namek,
                    price_sale1,
                    price_sale15,
                    price_buy1,
                    vahedk
                FROM dbo.kalas 
                WHERE ISNULL(namek, '') <> ''
                ORDER BY namek";
            
            using (SqlCommand cmd = new SqlCommand(query, conn))
            {
                using (SqlDataReader reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        var item = new
                        {
                            codek = reader["codek"] != DBNull.Value ? reader["codek"].ToString().Trim() : "",
                            namek = reader["namek"] != DBNull.Value ? reader["namek"].ToString().Trim() : "",
                            price_sale1 = reader["price_sale1"] != DBNull.Value ? reader["price_sale1"].ToString().Trim() : "0",
                            price_sale15 = reader["price_sale15"] != DBNull.Value ? reader["price_sale15"].ToString().Trim() : "0",
                            price_buy1 = reader["price_buy1"] != DBNull.Value ? reader["price_buy1"].ToString().Trim() : "0",
                            vahedk = reader["vahedk"] != DBNull.Value ? reader["vahedk"].ToString().Trim() : ""
                        };
                        
                        items.Add(item);
                    }
                }
            }
        }
        
        // ساخت پاسخ JSON
        var result = new
        {
            status = "ok",
            count = items.Count,
            items = items
        };
        
        var serializer = new JavaScriptSerializer();
        serializer.MaxJsonLength = int.MaxValue;
        Response.Write(serializer.Serialize(result));
    }
    catch (SqlException sqlEx)
    {
        Response.StatusCode = 500;
        var error = new
        {
            status = "error",
            message = "خطای SQL: " + sqlEx.Message,
            items = new object[] { }
        };
        var serializer = new JavaScriptSerializer();
        Response.Write(serializer.Serialize(error));
    }
    catch (Exception ex)
    {
        Response.StatusCode = 500;
        var error = new
        {
            status = "error",
            message = "خطا: " + ex.Message,
            items = new object[] { }
        };
        var serializer = new JavaScriptSerializer();
        Response.Write(serializer.Serialize(error));
    }
}
</script>
