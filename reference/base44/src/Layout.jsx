import React, { useState, useEffect } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { createPageUrl } from '@/utils';
import { base44 } from '@/api/base44Client';
import { Home, Users, UserPlus, Settings, LogOut, Menu, X, Church } from 'lucide-react';
import FeedbackButton from '@/components/FeedbackButton';
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet";

export default function Layout({ children, currentPageName }) {
  const [currentUser, setCurrentUser] = useState(null);
  const [userAccesses, setUserAccesses] = useState([]);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const location = useLocation();
  const navigate = useNavigate();

  useEffect(() => {
    const fetchUser = async () => {
      const user = await base44.auth.me();
      setCurrentUser(user);
      if (user) {
        const accesses = await base44.entities.UserAccess.filter({ user_email: user.email });
        setUserAccesses(accesses);
      }
    };
    fetchUser();
  }, []);

  const handleLogout = () => {
    base44.auth.logout();
  };

  const isAdmin = currentUser?.role === 'admin';
  const isSupervision = userAccesses.some(a => a.role === 'Membro da supervisão das campanhas');
  const hasAccess = isAdmin || userAccesses.length > 0;

  useEffect(() => {
    if (currentUser && !hasAccess && location.pathname !== '/Register') {
      navigate('/Register');
    }
  }, [currentUser, hasAccess, location.pathname]);

  const navItems = [
    { name: 'Register', icon: UserPlus, label: 'Cadastrar' },
  ];

  if (hasAccess) {
    navItems.unshift({ name: 'Home', icon: Home, label: 'Início' });
    navItems.push({ name: 'Converts', icon: Users, label: 'Convertidos' });
  }

  if (isAdmin || isSupervision) {
    navItems.push({ name: 'Admin', icon: Settings, label: 'Admin' });
  }

  const isActive = (pageName) => currentPageName === pageName;

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 to-blue-50">
      {/* Top Header */}
      <header className="bg-gradient-to-r from-[#1e3a5f] to-[#2563eb] text-white shadow-lg sticky top-0 z-50">
        <div className="max-w-4xl mx-auto px-4 py-3 flex items-center justify-between">
          <Link to={createPageUrl('Home')} className="flex items-center gap-2">
            <div className="w-10 h-10 bg-white/20 rounded-full flex items-center justify-center">
              <Church className="w-5 h-5" />
            </div>
            <div>
              <span className="font-bold text-lg">IEADPE</span>
              <span className="text-xs text-blue-100 block -mt-1">Novos Convertidos</span>
            </div>
          </Link>

          {/* Desktop Nav */}
          <nav className="hidden md:flex items-center gap-2">
            {navItems.map((item) => (
              <Link key={item.name} to={createPageUrl(item.name)}>
                <Button
                  variant={isActive(item.name) ? "secondary" : "ghost"}
                  size="sm"
                  className={isActive(item.name) 
                    ? "bg-white text-[#1e3a5f]" 
                    : "text-white hover:bg-white/20"
                  }
                >
                  <item.icon className="w-4 h-4 mr-1" />
                  {item.label}
                </Button>
              </Link>
            ))}
            <Button
              variant="ghost"
              size="sm"
              onClick={handleLogout}
              className="text-white hover:bg-white/20 ml-2"
            >
              <LogOut className="w-4 h-4" />
            </Button>
          </nav>

          {/* Mobile Menu Button */}
          <Sheet open={mobileMenuOpen} onOpenChange={setMobileMenuOpen}>
            <SheetTrigger asChild className="md:hidden">
              <Button variant="ghost" size="icon" className="text-white">
                <Menu className="w-6 h-6" />
              </Button>
            </SheetTrigger>
            <SheetContent side="right" className="w-72">
              <SheetHeader>
                <SheetTitle className="flex items-center gap-2 text-[#1e3a5f]">
                  <Church className="w-5 h-5" />
                  Menu
                </SheetTitle>
              </SheetHeader>
              <div className="mt-6 space-y-2">
                {navItems.map((item) => (
                  <Link 
                    key={item.name} 
                    to={createPageUrl(item.name)}
                    onClick={() => setMobileMenuOpen(false)}
                  >
                    <Button
                      variant={isActive(item.name) ? "default" : "ghost"}
                      className={`w-full justify-start ${
                        isActive(item.name) 
                          ? "bg-[#1e3a5f] text-white" 
                          : "text-slate-700"
                      }`}
                    >
                      <item.icon className="w-5 h-5 mr-3" />
                      {item.label}
                    </Button>
                  </Link>
                ))}
                <hr className="my-4" />
                <div className="px-3 py-2 text-sm text-slate-500">
                  <p className="font-medium text-slate-700">{currentUser?.full_name}</p>
                  <p className="text-xs">{currentUser?.email}</p>
                </div>
                <Button
                  variant="ghost"
                  onClick={handleLogout}
                  className="w-full justify-start text-red-600 hover:bg-red-50 hover:text-red-700"
                >
                  <LogOut className="w-5 h-5 mr-3" />
                  Sair
                </Button>
              </div>
            </SheetContent>
          </Sheet>
        </div>
      </header>

      {/* Main Content */}
      <main className="pb-20 md:pb-4">
        {children}
      </main>

      {/* Bottom Navigation (Mobile) */}
      <nav className="md:hidden fixed bottom-0 left-0 right-0 bg-white border-t shadow-lg z-50">
        <div className="flex justify-around">
          {navItems.map((item) => (
            <Link 
              key={item.name} 
              to={createPageUrl(item.name)}
              className={`flex flex-col items-center py-2 px-4 ${
                isActive(item.name) 
                  ? "text-[#1e3a5f]" 
                  : "text-slate-400"
              }`}
            >
              <item.icon className={`w-6 h-6 ${isActive(item.name) ? "stroke-[2.5]" : ""}`} />
              <span className="text-xs mt-1 font-medium">{item.label}</span>
              {isActive(item.name) && (
                <div className="absolute bottom-0 w-12 h-1 bg-[#1e3a5f] rounded-t-full" />
              )}
            </Link>
          ))}
        </div>
      </nav>
      <FeedbackButton />
    </div>
  );
}