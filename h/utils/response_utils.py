class ApiResponse:
    def __init__(self, status_code, message, data=None):
        self.status_code = status_code
        self.message = message
        self.data = data
    
    def to_dict(self):
        return {
            'statusCode': self.status_code,
            'message': self.message,
            'data': self.data
        }

def success_response(message="成功", data=None):
    """成功响应"""
    return ApiResponse(200, message, data).to_dict()

def error_response(message="失败", status_code=400, data=None):
    """错误响应"""
    return ApiResponse(status_code, message, data).to_dict()