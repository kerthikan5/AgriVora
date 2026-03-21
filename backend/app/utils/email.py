"""
**Email Utility**
Responsible for: Sending emails (e.g., OTP codes) using SMTP.
"""

import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

# 🌿 Email Configuration
# You should set these in your environment variables for security
SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 587
# USER: PLEASE FILL THESE OR SET ENV VARS
SENDER_EMAIL = os.getenv("SENDER_EMAIL", "your-email@gmail.com")
SENDER_PASSWORD = os.getenv("SENDER_PASSWORD", "your-app-password")

def send_otp_email(receiver_email: str, otp: str):
    # 🧪 DEBUG MODE: If credentials aren't set, print to terminal so you can test!
    if SENDER_EMAIL == "your-email@gmail.com" or SENDER_PASSWORD == "your-app-password":
        print("\n" + "="*50)
        print("DEBUG: SMTP Credentials not set in email.py")
        print(f"DEBUG: OTP for {receiver_email} is: {otp}")
        print("="*50 + "\n")
        return True

    try:
        msg = MIMEMultipart()
        msg['From'] = f"AgriVora Support <{SENDER_EMAIL}>"
        msg['To'] = receiver_email
        msg['Subject'] = "AgriVora Password Reset OTP"

        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e1e1e1; border-radius: 10px;">
                <h2 style="color: #2E7D32; text-align: center;">AgriVora</h2>
                <p>Hello,</p>
                <p>You requested a password reset for your AgriVora account. Use the following 6-digit OTP to verify your identity:</p>
                <div style="text-align: center; margin: 30px 0;">
                    <span style="font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #004D40; background: #e0f2f1; padding: 10px 20px; border-radius: 5px;">{otp}</span>
                </div>
                <p>This OTP is valid for 10 minutes. If you did not request this, please ignore this email.</p>
                <hr style="border: 0; border-top: 1px solid #eee; margin: 20px 0;">
                <p style="font-size: 12px; color: #888; text-align: center;">Team AgriVora • Smart Farming for You</p>
            </div>
        </body>
        </html>
        """
        msg.attach(MIMEText(body, 'html'))

        server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        server.starttls()
        server.login(SENDER_EMAIL, SENDER_PASSWORD)
        server.send_message(msg)
        server.quit()
        return True
    except Exception as e:
        print(f"Error sending email: {str(e)}")
        return False
