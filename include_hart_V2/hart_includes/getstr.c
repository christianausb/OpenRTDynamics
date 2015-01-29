
/**-----------------------------------------------------------------------------------
 *  Copyright (C) 2006  Roberto Bucher (roberto.bucher@supsi.ch)
 *  Copyright (C) 2008  Holger Nahrstaedt
 *
 *  This file is part of HART, the Hardware Access in Real Time Toolbox for Scilab/Scicos.
 *
 *  HART is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU Lesser General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  HART is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with HART; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *--------------------------------------------------------------------------------- */

#include "getstr.h"

void par_getstr(char * str, int par[], int init, int len)
{
  int i;
  int j=0;

  for(i=init;i<init+len;i++)
    str[j++]=(char) par[i];

  str[j]='\0';
}
