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
            // خواندن بدنه درخواست (JSON)
            string body = new StreamReader(Request.InputStream).ReadToEnd();

            if (string.IsNullOrEmpty(body))
            {
                Response.Write("{\"status\":\"error\",\"message\":\"بدون داده\"}");
                return;
            }

            var js = new JavaScriptSerializer();
            dynamic data = null;

            try
            {
                data = js.DeserializeObject(body);
            }
            catch (Exception ex)
            {
                Response.Write("{\"status\":\"error\",\"message\":\"خطا در خواندن JSON: " + ex.Message.Replace("\"", "'") + "\"}");
                return;
            }

            // فیلدهای مورد نیاز از JSON
            string username     = "";
            string password     = "";
            string firstName    = "";
            string lastName     = "";
            byte   statusId     = 1; // FK_Status_ID پیش‌فرض = 1
            int    userLevelId  = 5; // نقش پیش‌فرض = مشترک

            if (data != null)
            {
                if (data.ContainsKey("username"))
                    username = data["username"] != null ? data["username"].ToString() : "";

                if (data.ContainsKey("password"))
                    password = data["password"] != null ? data["password"].ToString() : "";

                if (data.ContainsKey("first_name"))
                    firstName = data["first_name"] != null ? data["first_name"].ToString() : "";

                if (data.ContainsKey("last_name"))
                    lastName = data["last_name"] != null ? data["last_name"].ToString() : "";

                if (data.ContainsKey("status_id"))
                {
                    byte tmpStatus;
                    if (byte.TryParse(data["status_id"].ToString(), out tmpStatus))
                        statusId = tmpStatus;
                }

                if (data.ContainsKey("role_id"))
                {
                    int tmpRole;
                    if (int.TryParse(data["role_id"].ToString(), out tmpRole))
                        userLevelId = tmpRole;
                }
            }

            // پر کردن مقادیر خالی طبق شرطی که گفتی
            if (string.IsNullOrEmpty(username))
            {
                Response.Write("{\"status\":\"error\",\"message\":\"نام کاربری الزامی است\"}");
                return;
            }

            if (string.IsNullOrEmpty(password))
            {
                Response.Write("{\"status\":\"error\",\"message\":\"رمز عبور الزامی است\"}");
                return;
            }

            if (string.IsNullOrEmpty(firstName))
                firstName = username;

            if (string.IsNullOrEmpty(lastName))
                lastName = username;

            // اتصال به دیتابیس
            string connectionString = "Server=194.5.195.93;Database=millionaire;User Id=sa;Password=2901;";

            using (SqlConnection conn = new SqlConnection(connectionString))
            {
                try
                {
                    conn.Open();
                }
                catch (SqlException connEx)
                {
                    Response.Write("{\"status\":\"error\",\"message\":\"خطا در اتصال به دیتابیس: " + connEx.Message.Replace("\"", "'") + "\"}");
                    return;
                }

                try
                {
                    // فرض بر این است که User_ID در جدول dbo.Users شناسه خودکار (IDENTITY) است
                    string query = @"
                        INSERT INTO dbo.Users
                            (User_Name, User_Password, User_FirstName, User_LastName, FK_Status_ID, FK_UserLevel_ID)
                        VALUES
                            (@User_Name, @User_Password, @User_FirstName, @User_LastName, @FK_Status_ID, @FK_UserLevel_ID);
                    ";

                    using (SqlCommand cmd = new SqlCommand(query, conn))
                    {
                        cmd.Parameters.AddWithValue("@User_Name",
                            username.Length > 50 ? username.Substring(0, 50) : username);

                        cmd.Parameters.AddWithValue("@User_Password",
                            password.Length > 50 ? password.Substring(0, 50) : password);

                        cmd.Parameters.AddWithValue("@User_FirstName",
                            string.IsNullOrEmpty(firstName) ? (object)DBNull.Value :
                            (firstName.Length > 50 ? firstName.Substring(0, 50) : firstName));

                        cmd.Parameters.AddWithValue("@User_LastName",
                            string.IsNullOrEmpty(lastName) ? (object)username :
                            (lastName.Length > 50 ? lastName.Substring(0, 50) : lastName));

                        cmd.Parameters.AddWithValue("@FK_Status_ID", statusId);
                        cmd.Parameters.AddWithValue("@FK_UserLevel_ID", userLevelId);

                        cmd.ExecuteNonQuery();
                    }

                    Response.Write("{\"status\":\"ok\",\"message\":\"کاربر با موفقیت ذخیره شد\"}");
                }
                catch (SqlException sqlEx)
                {
                    Response.Write("{\"status\":\"error\",\"message\":\"خطا در ذخیره‌سازی: " + sqlEx.Message.Replace("\"", "'") + "\"}");
                }
                catch (Exception ex)
                {
                    Response.Write("{\"status\":\"error\",\"message\":\"خطا: " + ex.Message.Replace("\"", "'") + "\"}");
                }
            }
        }
        catch (Exception ex)
        {
            Response.Write("{\"status\":\"error\",\"message\":\"خطای عمومی: " + ex.Message.Replace("\"", "'") + "\"}");
        }
    }
</script>
