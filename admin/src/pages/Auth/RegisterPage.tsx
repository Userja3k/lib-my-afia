import React from 'react';
import { useNavigate } from 'react-router-dom';
import AuthForm from '../components/auth/AuthForm';

const RegisterPage: React.FC = () => {
  const navigate = useNavigate();
  const toggleMode = () => {
    // Since this is a dedicated register page, we can navigate to /auth for signin
    navigate('/auth');
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-cyan-50 via-blue-50 to-slate-50 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="bg-white rounded-2xl shadow-xl border border-slate-100 p-8">
          <AuthForm mode="signup" onToggleMode={toggleMode} />
        </div>
      </div>
    </div>
  );
};

export default RegisterPage;
