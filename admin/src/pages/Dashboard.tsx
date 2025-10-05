import React from 'react';
import { useAuth } from '../contexts/AuthContext';
import PatientDashboard from '../components/dashboard/PatientDashboard';
import DoctorDashboard from '../components/dashboard/DoctorDashboard';
import AdminDashboard from '../components/dashboard/AdminDashboard';

const Dashboard: React.FC = () => {
  const { profile } = useAuth();

  if (!profile) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-cyan-600"></div>
      </div>
    );
  }

  const renderDashboard = () => {
    switch (profile.role) {
      case 'patient':
        return <PatientDashboard />;
      case 'doctor':
        return <DoctorDashboard />;
      case 'admin':
        return <AdminDashboard />;
      default:
        return <div>Rôle non reconnu</div>;
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">
            Bonjour, {profile.firstName} {profile.lastName}
          </h1>
          <p className="text-slate-600 capitalize">
            Dashboard {profile.role}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <div className={`w-2 h-2 rounded-full ${profile.isOnline ? 'bg-green-500' : 'bg-slate-400'}`} />
          <span className="text-sm text-slate-600">
            {profile.isOnline ? 'En ligne' : 'Hors ligne'}
          </span>
        </div>
      </div>
      
      {renderDashboard()}
    </div>
  );
};

export default Dashboard;